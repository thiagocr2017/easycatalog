import 'package:flutter/material.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Administración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('Estilo del Catálogo'),
            subtitle: const Text('Colores, fuentes y logo'),
            onTap: () => Navigator.pushNamed(context, '/catalog/style'),
          ),
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Configuración del Vendedor'),
            subtitle: const Text('Nombre, teléfono y mensaje de WhatsApp'),
            onTap: () => Navigator.pushNamed(context, '/catalog/seller_settings'),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Productos'),
            subtitle: const Text('Agregar o editar productos'),
            onTap: () => Navigator.pushNamed(context, '/admin/products'),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Secciones'),
            subtitle: const Text('Organiza tus categorías de productos'),
            onTap: () => Navigator.pushNamed(context, '/admin/sections'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Ver carpeta de imágenes'),
            subtitle: const Text('Abrir directorio interno con imágenes'),
            onTap: () => Navigator.pushNamed(context, '/admin/folder_view'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Vista previa del catálogo'),
            subtitle: const Text('Generar y compartir PDF'),
            onTap: () => Navigator.pushNamed(context, '/catalog/pdf_preview'),
          ),
        ],
      ),
    );
  }
}
