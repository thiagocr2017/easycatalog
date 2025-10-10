import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = 'catalogo.db';
  static const _databaseVersion = 2;

  static const tableSections = 'sections';
  static const tableProducts = 'products';
  static const tableSettings = 'settings';
  static const tableLogs = 'product_logs';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ───────────────────────────────
  // CREACIÓN INICIAL
  // ───────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sortOrder INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableProducts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        imagePath TEXT,
        sectionId INTEGER,
        isDepleted INTEGER DEFAULT 0,
        depletedAt TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        action TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES $tableProducts(id) ON DELETE CASCADE
      )
    ''');
  }

  // ───────────────────────────────
  // MIGRACIONES AUTOMÁTICAS
  // ───────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('⬆️ Actualizando base de datos de versión $oldVersion → $newVersion');

    if (oldVersion < 2) {
      // createdAt en products
      final cols = await db.rawQuery("PRAGMA table_info($tableProducts)");
      final hasCreatedAt = cols.any((c) => c['name'] == 'createdAt');
      if (!hasCreatedAt) {
        await db.execute("ALTER TABLE $tableProducts ADD COLUMN createdAt TEXT");
        print('🆕 Columna createdAt añadida');
      }

      // sortOrder en sections
      final cols2 = await db.rawQuery("PRAGMA table_info($tableSections)");
      final hasSortOrder = cols2.any((c) => c['name'] == 'sortOrder');
      if (!hasSortOrder) {
        await db.execute("ALTER TABLE $tableSections ADD COLUMN sortOrder INTEGER DEFAULT 0");
        print('🆕 Columna sortOrder añadida');
      }

      // tabla product_logs
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final hasLogs = tables.any((t) => t['name'] == tableLogs);
      if (!hasLogs) {
        await db.execute('''
          CREATE TABLE $tableLogs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            action TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (productId) REFERENCES $tableProducts(id) ON DELETE CASCADE
          )
        ''');
        print('🆕 Tabla product_logs creada');
      }
    }
  }

  // ───────────────────────────────
  // MÉTODOS DE MANTENIMIENTO
  // ───────────────────────────────
  Future<void> clearDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await deleteDatabase(path);
    print('🧹 Base de datos eliminada completamente.');
  }

  Future<void> factoryReset() async {
    final db = await database;
    await db.delete('product_logs');
    await db.delete(tableProducts);
    await db.delete(tableSections);
    await db.delete(tableSettings);

    // valores por defecto (verde lima)
    await db.insert(tableSettings,
        {'key': 'style.backgroundColor', 'value': '0xFFE1F6B4'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert(tableSettings,
        {'key': 'style.highlightColor', 'value': '0xFF50B203'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert(tableSettings,
        {'key': 'style.infoBoxColor', 'value': '0xFFEEE9CC'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert(tableSettings,
        {'key': 'style.textColor', 'value': '0xFF222222'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    print('🔁 Reinicio de fábrica completado.');
  }

  // ───────────────────────────────
  // SETTINGS
  // ───────────────────────────────
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
    final res =
    await db.query(tableSettings, where: 'key = ?', whereArgs: [key]);
    return res.isNotEmpty ? res.first['value'] as String? : null;
  }

  // ───────────────────────────────
  // COMPATIBILIDAD CON VENDEDOR MÚLTIPLE
  // ───────────────────────────────
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

  // ───────────────────────────────
  // SECCIONES
  // ───────────────────────────────
  Future<void> ensureSectionOrderColumn() async {
    final db = await database;
    final res = await db.rawQuery("PRAGMA table_info($tableSections)");
    final hasSortOrder = res.any((col) => col['name'] == 'sortOrder');
    if (!hasSortOrder) {
      await db.execute(
          "ALTER TABLE $tableSections ADD COLUMN sortOrder INTEGER DEFAULT 0");
    }
  }

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

  // ───────────────────────────────
  // PRODUCTOS
  // ───────────────────────────────
  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableProducts, row);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query(tableProducts);
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

  // ───────────────────────────────
  // LOGS DE PRODUCTOS
  // ───────────────────────────────
  Future<void> insertProductLog(int productId, String action) async {
    final db = await database;
    await db.insert(tableLogs, {
      'productId': productId,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
    print('🧾 Log insertado: producto=$productId acción=$action');
  }

  Future<List<Map<String, dynamic>>> getProductLogs(int productId) async {
    final db = await database;
    return await db.query(
      tableLogs,
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'timestamp DESC',
    );
  }
}
