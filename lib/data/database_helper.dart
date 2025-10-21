// 📄 lib/data/database_helper.dart
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product_image_setting.dart';

class DatabaseHelper {
  static const _databaseName = 'catalogo.db';
  static const _databaseVersion = 1;

  static const tableSections = 'sections';
  static const tableProducts = 'products';
  static const tableSettings = 'settings';
  static const tableProductLogs = 'product_logs';
  static const tablePaymentMethods = 'payment_methods';
  static const tableProductImageSettings = 'product_image_settings';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  // Getter principal
  // ─────────────────────────────────────────────
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    await ensureProductSortOrderColumn(); // ✅ crea sortOrder si falta
    await ensureProductImageSettingsTable(); // nueva tabla
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  // ─────────────────────────────────────────────
  // CREACIÓN DE TODAS LAS TABLAS
  // ─────────────────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    // Tabla de secciones
    await db.execute('''
      CREATE TABLE $tableSections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sortOrder INTEGER DEFAULT 0
      )
    ''');

    // Tabla de productos
    await db.execute('''
      CREATE TABLE $tableProducts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        imagePath TEXT,
        sectionId INTEGER,
        isDepleted INTEGER DEFAULT 0,
        createdAt TEXT,
        depletedAt TEXT,
        sortOrder INTEGER DEFAULT 0,
        FOREIGN KEY (sectionId) REFERENCES $tableSections(id) ON DELETE SET NULL
      )
    ''');

    // Tabla de configuraciones
    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Tabla de logs de productos
    await db.execute('''
      CREATE TABLE $tableProductLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        action TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES $tableProducts(id) ON DELETE CASCADE
      )
    ''');

    // Tabla de métodos de pago
    await db.execute('''
      CREATE TABLE $tablePaymentMethods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        info TEXT,
        beneficiary TEXT,
        logoPath TEXT
      )
    ''');

    // Nueva tabla de configuraciones de imagen
    await db.execute('''
      CREATE TABLE $tableProductImageSettings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        zoom REAL DEFAULT 1.0,
        offsetX REAL DEFAULT 0.0,
        offsetY REAL DEFAULT 0.0,
        FOREIGN KEY (productId) REFERENCES $tableProducts(id) ON DELETE CASCADE
      )
    ''');
  }
  // ✅ Verifica si existe sortOrder y lo agrega si falta
  // ─────────────────────────────────────────────
  // COLUMNAS Y TABLAS EXTRA
  // ─────────────────────────────────────────────
  Future<void> ensureProductSortOrderColumn() async {
    final db = await database;
    final res = await db.rawQuery('PRAGMA table_info($tableProducts)');
    final hasSortOrder = res.any((col) => col['name'] == 'sortOrder');
    if (!hasSortOrder) {
      await db.execute('ALTER TABLE $tableProducts ADD COLUMN sortOrder INTEGER DEFAULT 0');
    }
  }

  // ───────────────────────────────
  // Tabla de la imagen de producto
  // ───────────────────────────────
  Future<void> ensureProductImageSettingsTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableProductImageSettings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        zoom REAL DEFAULT 1.0,
        offsetX REAL DEFAULT 0.0,
        offsetY REAL DEFAULT 0.0,
        FOREIGN KEY (productId) REFERENCES $tableProducts(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─────────────────────────────────────────────
  // CONFIGURACIÓN GENERAL (SETTINGS)
  // ─────────────────────────────────────────────
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query(tableSettings, where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) return res.first['value'] as String?;
    return null;
  }

  // ─────────────────────────────────────────────
  // CONFIGURACIÓN POR VENDEDOR
  // ─────────────────────────────────────────────
  Future<void> setSellerSetting(int sellerId, String key, String value) async {
    final db = await database;
    await db.insert(
      tableSettings,
      {'key': 'seller.$sellerId.$key', 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getSellerSettings(int sellerId) async {
    final db = await database;
    final res = await db.query(
      tableSettings,
      where: 'key LIKE ?',
      whereArgs: ['seller.$sellerId.%'],
    );

    final map = <String, String>{};
    for (final row in res) {
      final key = (row['key'] as String).split('.').last;
      map[key] = row['value'] as String;
    }
    return map;
  }

  Future<List<int>> getAllSellerIds() async {
    final db = await database;
    final res = await db.query(
      tableSettings,
      columns: ['key'],
      where: 'key LIKE ?',
      whereArgs: ['seller.%.name'],
    );

    final ids = <int>{};
    for (final r in res) {
      final parts = (r['key'] as String).split('.');
      if (parts.length >= 3) ids.add(int.tryParse(parts[1]) ?? 0);
    }
    return ids.toList()..sort();
  }

  // ─────────────────────────────────────────────
  // CONFIGURACIÓN DE IMAGEN POR PRODUCTO
  // ─────────────────────────────────────────────
  Future<void> upsertImageSetting(ProductImageSetting setting) async {
    final db = await database;

    // Verifica si ya existe una configuración para este producto
    final existing = await db.query(
      tableProductImageSettings,
      where: 'productId = ?',
      whereArgs: [setting.productId],
    );

    if (existing.isNotEmpty) {
      // ✅ Actualiza los valores existentes
      /*await db.update(
        tableProductImageSettings,
        setting.toMap(),
        where: 'productId = ?',
        whereArgs: [setting.productId],
      );*/

      // 🔹 eliminamos el 'id' del mapa para evitar conflicto
      final data = Map<String, dynamic>.from(setting.toMap())..remove('id');

      await db.update(
        tableProductImageSettings,
        data,
        where: 'productId = ?',
        whereArgs: [setting.productId],
      );

    } else {
      // ✅ Inserta nueva configuración
      await db.insert(
        tableProductImageSettings,
        setting.toMap(),
      );
    }
  }


  Future<ProductImageSetting?> getImageSetting(int productId) async {
    final db = await database;
    final res = await db.query(
      tableProductImageSettings,
      where: 'productId = ?',
      whereArgs: [productId],
    );
    if (res.isNotEmpty) return ProductImageSetting.fromMap(res.first);
    return null;
  }

  // ─────────────────────────────────────────────
  // SECCIONES
  // ─────────────────────────────────────────────
  Future<int> insertSection(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableSections, row);
  }

  Future<List<Map<String, dynamic>>> getSections() async {
    final db = await database;
    return await db.query(tableSections, orderBy: 'sortOrder ASC');
  }

  Future<int> updateSection(Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      tableSections,
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<int> deleteSection(int id) async {
    final db = await database;
    return await db.delete(tableSections, where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────
  // PRODUCTOS
  // ─────────────────────────────────────────────
  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableProducts, row);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query(tableProducts, orderBy: 'sectionId ASC, sortOrder ASC');
  }

  Future<int> updateProduct(Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      tableProducts,
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(tableProducts, where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────
  // LOGS PRODUCTOS
  // ─────────────────────────────────────────────
  Future<void> insertProductLog(int productId, String action) async {
    final db = await database;
    await db.insert(
      tableProductLogs,
      {
        'productId': productId,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getProductLogs(int productId) async {
    final db = await database;
    return await db.query(
      tableProductLogs,
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'timestamp DESC',
    );
  }

  // ─────────────────────────────────────────────
  // MÉTODOS DE PAGO
  // ─────────────────────────────────────────────
  Future<int> insertPaymentMethod(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tablePaymentMethods, row);
  }

  Future<int> updatePaymentMethod(Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      tablePaymentMethods,
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<int> deletePaymentMethod(int id) async {
    final db = await database;
    return await db.delete(tablePaymentMethods, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final db = await database;
    return await db.query(tablePaymentMethods);
  }

  // ─────────────────────────────────────────────
// ELIMINAR PRODUCTO CON DEPENDENCIAS (Y SU IMAGEN)
// ─────────────────────────────────────────────
  Future<void> deleteProductCascade(int productId) async {
    final db = await database;

    // 🗑️ 1️⃣ Eliminar registros relacionados en product_logs
    await db.delete(
      tableProductLogs,
      where: 'productId = ?',
      whereArgs: [productId],
    );

    // 🗑️ 2️⃣ Eliminar registros en configuraciones de imagen (si existen)
    try {
      await db.delete(
        tableProductImageSettings,
        where: 'productId = ?',
        whereArgs: [productId],
      );
    } catch (e) {
      debugPrint('⚠️ No se pudo eliminar configuración de imagen: $e');
    }

    // 🧹 3️⃣ Finalmente, eliminar el producto
    await db.delete(
      tableProducts,
      where: 'id = ?',
      whereArgs: [productId],
    );

    // (Opcional) si tuvieras otras tablas dependientes, puedes agregarlas aquí
  }

// ─────────────────────────────────────────────
  // REINICIO COMPLETO
  // ─────────────────────────────────────────────
  /*Future<void> clearDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await deleteDatabase(path);
  }*/
}
