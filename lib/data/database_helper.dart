import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = 'catalogo.db';
  static const _databaseVersion = 1;

  static const tableSections = 'sections';
  static const tableProducts = 'products';
  static const tableSettings = 'settings';


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

    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
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
        isDepleted INTEGER DEFAULT 0
        depletedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // ───────────────────────────────
  // Métodos para Settings
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
    final res = await db.query(tableSettings, where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  // ───────────────────────────────
// Vendedores (múltiples)
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
  // Secciones
  // ───────────────────────────────
  Future<int> insertSection(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(tableSections, row);
  }

  Future<List<Map<String, dynamic>>> getSections() async {
    final db = await database;
    return await db.query(tableSections);
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
  // Productos
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

  Future<void> clearDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await deleteDatabase(path);
  }
}
