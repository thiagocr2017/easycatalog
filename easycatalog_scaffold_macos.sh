#!/usr/bin/env bash
# easycatalog_scaffold_macos.sh
# Purpose: Create folders and stub files for the EasyCatalog app (Flutter, macOS-ready).
# Usage: Run from the root of your Flutter project: bash easycatalog_scaffold_macos.sh
# Notes:
#  - This only scaffolds files/directories. It does NOT run 'flutter pub add'.
#  - Make sure you've already created the Flutter project and enabled macOS support.

set -euo pipefail

ROOT_DIR="$(pwd)"
if [[ ! -f "$ROOT_DIR/pubspec.yaml" ]]; then
  echo "✖ ERROR: pubspec.yaml not found. Run this script from the Flutter project root."
  exit 1
fi

APP_NAME="$(grep -m1 '^name:' pubspec.yaml | awk '{print $2}' || echo 'easycatalog')"
echo "➤ Scaffolding EasyCatalog structure in: $ROOT_DIR (app: $APP_NAME)"

# 1) Directories
dirs=(
  "lib/models"
  "lib/data"
  "lib/services"
  "lib/widgets"
  "lib/pages"
  "lib/pages/admin"
  "lib/pages/catalog"
  "assets/images"
  "assets/fonts"
)
for d in "${dirs[@]}"; do
  mkdir -p "$d"
done
touch assets/images/.gitkeep assets/fonts/.gitkeep

# 2) main.dart
cat > lib/main.dart <<'DART'
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/admin/admin_home_page.dart';
import 'pages/admin/sections_page.dart';
import 'pages/admin/products_page.dart';
import 'pages/admin/depleted_products_page.dart';
import 'pages/catalog/catalog_style_page.dart';
import 'pages/catalog/pdf_preview_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EasyCatalogApp());
}

class EasyCatalogApp extends StatelessWidget {
  const EasyCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyCatalog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePage(),
        '/admin': (_) => const AdminHomePage(),
        '/admin/sections': (_) => const SectionsPage(),
        '/admin/products': (_) => const ProductsPage(),
        '/admin/depleted': (_) => const DepletedProductsPage(),
        '/catalog/style': (_) => const CatalogStylePage(),
        '/catalog/preview': (_) => const PdfPreviewPage(),
      },
    );
  }
}
DART

# 3) Models
cat > lib/models/section.dart <<'DART'
class Section {
  final int? id;
  final String name;

  const Section({this.id, required this.name});

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
      };

  factory Section.fromMap(Map<String, Object?> map) => Section(
        id: map['id'] as int?,
        name: (map['name'] ?? '') as String,
      );
}
DART

cat > lib/models/product.dart <<'DART'
class Product {
  final int? id;
  final String name;
  final String description;
  final double price;
  final String? imagePath;
  final int sectionId;
  final bool isDepleted;
  final DateTime createdAt;
  final DateTime? depletedAt;

  const Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.sectionId,
    this.isDepleted = false,
    required this.createdAt,
    this.depletedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'imagePath': imagePath,
        'sectionId': sectionId,
        'isDepleted': isDepleted ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'depletedAt': depletedAt?.toIso8601String(),
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int?,
        name: (map['name'] ?? '') as String,
        description: (map['description'] ?? '') as String,
        price: (map['price'] ?? 0).toDouble(),
        imagePath: map['imagePath'] as String?,
        sectionId: (map['sectionId'] ?? 0) as int,
        isDepleted: (map['isDepleted'] ?? 0) == 1,
        createdAt: DateTime.tryParse((map['createdAt'] ?? '') as String) ?? DateTime.now(),
        depletedAt: (map['depletedAt'] as String?) != null
            ? DateTime.tryParse(map['depletedAt'] as String)
            : null,
      );
}
DART

# 4) Database helper (SQLite)
cat > lib/data/database_helper.dart <<'DART'
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'catalogo.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            price REAL NOT NULL,
            imagePath TEXT,
            sectionId INTEGER NOT NULL,
            isDepleted INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            depletedAt TEXT,
            FOREIGN KEY (sectionId) REFERENCES sections(id) ON DELETE CASCADE
          );
        ''');
      },
    );
  }

  // --- Sections CRUD (minimal stubs) ---
  Future<int> insertSection(Map<String, Object?> data) async {
    final db = await database;
    return db.insert('sections', data);
  }

  Future<List<Map<String, Object?>>> getSections() async {
    final db = await database;
    return db.query('sections', orderBy: 'name');
  }

  Future<int> updateSection(Map<String, Object?> data, int id) async {
    final db = await database;
    return db.update('sections', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSection(int id) async {
    final db = await database;
    return db.delete('sections', where: 'id = ?', whereArgs: [id]);
  }

  // --- Products stubs (expand later) ---
  Future<int> insertProduct(Map<String, Object?> data) async {
    final db = await database;
    return db.insert('products', data);
  }

  Future<List<Map<String, Object?>>> getProducts({bool? depleted}) async {
    final db = await database;
    if (depleted == null) return db.query('products', orderBy: 'createdAt DESC');
    return db.query('products',
        where: 'isDepleted = ?', whereArgs: [depleted ? 1 : 0], orderBy: 'createdAt DESC');
  }
}
DART

# 5) Pages (stubs)
cat > lib/pages/home_page.dart <<'DART'
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EasyCatalog')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/catalog/preview'),
              child: const Text('Generar Catálogo PDF'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/admin'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Panel de Administración'),
            ),
          ],
        ),
      ),
    );
  }
}
DART

cat > lib/pages/admin/admin_home_page.dart <<'DART'
import 'package:flutter/material.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Gestionar Secciones'),
            onTap: () => Navigator.pushNamed(context, '/admin/sections'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Gestionar Productos'),
            onTap: () => Navigator.pushNamed(context, '/admin/products'),
          ),
          ListTile(
            leading: const Icon(Icons.remove_shopping_cart_outlined),
            title: const Text('Productos Agotados'),
            onTap: () => Navigator.pushNamed(context, '/admin/depleted'),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Personalizar Estilo del Catálogo'),
            onTap: () => Navigator.pushNamed(context, '/catalog/style'),
          ),
        ],
      ),
    );
  }
}
DART

cat > lib/pages/admin/sections_page.dart <<'DART'
import 'package:flutter/material.dart';

class SectionsPage extends StatefulWidget {
  const SectionsPage({super.key});
  @override
  State<SectionsPage> createState() => _SectionsPageState();
}

class _SectionsPageState extends State<SectionsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secciones')),
      body: const Center(child: Text('TODO: Listar/crear/editar secciones')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
DART

cat > lib/pages/admin/products_page.dart <<'DART'
import 'package:flutter/material.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: const Center(child: Text('TODO: Listar/crear/editar productos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
DART

cat > lib/pages/admin/depleted_products_page.dart <<'DART'
import 'package:flutter/material.dart';

class DepletedProductsPage extends StatelessWidget {
  const DepletedProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agotados')),
      body: const Center(child: Text('TODO: Listar productos agotados')),
    );
  }
}
DART

cat > lib/pages/catalog/catalog_style_page.dart <<'DART'
import 'package:flutter/material.dart';

class CatalogStylePage extends StatefulWidget {
  const CatalogStylePage({super.key});

  @override
  State<CatalogStylePage> createState() => _CatalogStylePageState();
}

class _CatalogStylePageState extends State<CatalogStylePage> {
  // Example style settings (store later in DB/preferences)
  Color primaryColor = Colors.teal;
  Color textColor = Colors.black87;
  double productTitleSize = 16;
  double spacing = 8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estilo del Catálogo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              const Text('Tamaño título producto'),
              Expanded(
                child: Slider(
                  min: 12,
                  max: 24,
                  divisions: 12,
                  value: productTitleSize,
                  label: productTitleSize.toStringAsFixed(0),
                  onChanged: (v) => setState(() => productTitleSize = v),
                ),
              )
            ]),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // TODO: persist style
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Estilo guardado (pendiente)')));
              },
              child: const Text('Guardar'),
            )
          ],
        ),
      ),
    );
  }
}
DART

cat > lib/pages/catalog/pdf_preview_page.dart <<'DART'
import 'package:flutter/material.dart';

class PdfPreviewPage extends StatelessWidget {
  const PdfPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista previa PDF')),
      body: const Center(child: Text('TODO: Mostrar vista previa usando printing.PdfPreview')),
    );
  }
}
DART

# 6) Services (stubs)
cat > lib/services/pdf_service.dart <<'DART'
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class PdfService {
  Future<Uint8List> buildCatalogPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Text('EasyCatalog - PDF (pendiente)'),
        ),
      ),
    );
    return doc.save();
  }
}
DART

# 7) Widgets (stubs)
cat > lib/widgets/confirm_dialog.dart <<'DART'
import 'package:flutter/material.dart';

Future<bool> confirmDialog(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
      ],
    ),
  );
  return result ?? false;
}
DART

echo "✅ Done. Basic structure created."
