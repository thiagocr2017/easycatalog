import 'package:flutter/material.dart';

// Importaciones de tus páginas
import 'pages/admin/admin_home_page.dart';
import 'pages/admin/products_page.dart';
import 'pages/admin/sections_page.dart';
import 'pages/admin/folder_view_page.dart';
import 'pages/catalog/catalog_style_page.dart';
import 'pages/catalog/seller_settings_page.dart';
import 'pages/catalog/pdf_preview_page.dart';
import 'pages/admin/depleted_products_page.dart';


void main() {
  runApp(const EasyCatalogApp());
}

class EasyCatalogApp extends StatelessWidget {
  const EasyCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyCatalog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3A8FB7)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
          backgroundColor: Color(0xFF3A8FB7),
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF3A8FB7),
          foregroundColor: Colors.white,
        ),
      ),

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
      },
    );
  }
}
