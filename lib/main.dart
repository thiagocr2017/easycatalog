import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';

// Importaciones de tus páginas
import 'pages/admin/admin_home_page.dart';
import 'pages/admin/products_page.dart';
import 'pages/admin/sections_page.dart';
import 'pages/admin/folder_view_page.dart';
import 'pages/catalog/catalog_style_page.dart';
import 'pages/catalog/seller_settings_page.dart';
import 'pages/catalog/pdf_preview_page.dart';
import 'pages/admin/depleted_products_page.dart';
import 'pages/admin/import_export_page.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚙️ Solo para entornos de escritorio (macOS, Windows, Linux)
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    // Obtiene la lista de pantallas disponibles
    final screens = await getScreenList();
    final screen = screens.first; // pantalla principal
    final frame = screen.frame;

    // 📐 Tamaño inicial deseado
    const initialWidth = 600.0;
    const initialHeight = 800.0;

    // 📍 Calcula posición centrada
    final left = (frame.width - initialWidth) / 2;
    final top = (frame.height - initialHeight) / 2;

    // 🔹 Configura ventana
    setWindowTitle('EasyCatalog');
    setWindowMinSize(const Size(400, 700));
    setWindowMaxSize(Size.infinite);
    setWindowFrame(
      Rect.fromLTWH(left, top, initialWidth, initialHeight),
    );
  }

  runApp(const EasyCatalogApp());
}

class EasyCatalogApp extends StatelessWidget {
  const EasyCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4B0082); // Índigo profundo
    const accentColor = Color(0xFFFF0080);  // Rosa eléctrico
    const cyanColor = Color(0xFF00BFFF);    // Azul eléctrico

    return MaterialApp(
      title: 'EasyCatalog',
      debugShowCheckedModeBanner: false,

      // 🎨 Tema claro — elegante y tecnológico
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: cyanColor,
          surface: Color(0xFFF4F4F4),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F9FB),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
        ),
      ),

      // 🌙 Tema oscuro — moderno y tecnológico
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: accentColor,
          secondary: cyanColor,
          surface: Color(0xFF2A2A2A),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
        ),
        cardColor: const Color(0xFF2A2A2A),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),

      // 🔄 Seguir el modo del sistema
      themeMode: ThemeMode.system,

      // Página inicial
      home: const AdminHomePage(),

      // Rutas del proyecto
      routes: {
        '/admin/products': (context) => const ProductsPage(),
        '/admin/sections': (context) => const SectionsPage(),
        '/admin/folder_view': (context) => const FolderViewPage(),
        '/catalog/style': (context) => const CatalogStylePage(),
        '/catalog/seller_settings': (context) => const SellerSettingsPage(),
        '/catalog/pdf_preview': (context) => const PdfPreviewPage(),
        '/admin/depleted': (context) => const DepletedProductsPage(),
        '/admin/import_export': (context) => const ImportExportPage(),
      },
    );
  }
}
