import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/product.dart';
import '../../services/pdf_service.dart';
import '../catalog/pdf_preview_page.dart';
import 'product_history_page.dart';

class DepletedProductsPage extends StatefulWidget {
  const DepletedProductsPage({super.key});

  @override
  State<DepletedProductsPage> createState() => _DepletedProductsPageState();
}

class _DepletedProductsPageState extends State<DepletedProductsPage> {
  final _db = DatabaseHelper.instance;
  final _pdfService = PdfService();
  List<Product> _depleted = [];

  @override
  void initState() {
    super.initState();
    _loadDepleted();
  }

  Future<void> _loadDepleted() async {
    final data = await _db.getProducts();
    setState(() {
      _depleted = data.map((e) => Product.fromMap(e))
          .where((p) => p.isDepleted)
          .toList();
    });
  }

  Future<void> _reactivateProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reactivar producto'),
        content: Text('¿Deseas reactivar "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, reactivar')),
        ],
      ),
    );
    if (confirm != true) return;

    final updated = p.toMap();
    updated['isDepleted'] = 0;
    updated['depletedAt'] = null;
    await _db.updateProduct(updated);
    await _db.insertProductLog(p.id!, 'reactivado');

    if (!mounted) return;
    setState(() {
      _depleted.remove(p);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Producto "${p.name}" reactivado')),
    );
  }

  void _previewPdf() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          customBuilder: (format) async =>
          await _pdfService.buildDepletedProductsReport(_depleted),
          title: 'Vista previa de productos agotados',
          fileName: 'productos_agotados.pdf',
        ),
      ),
    );
  }

  /// ✅ Nueva función: confirma y elimina producto + imagen
  Future<void> _confirmAndDeleteProduct(Product p) async {
    // ⚡ Diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que deseas eliminar "${p.name}"?\n'
              'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 🗑️ 1️⃣ Borra imagen local (si existe)
    if (p.imagePath != null && File(p.imagePath!).existsSync()) {
      try {
        await File(p.imagePath!).delete();
      } catch (e) {
        debugPrint('⚠️ No se pudo eliminar la imagen: $e');
      }
    }

    // 🧹 2️⃣ Borra el producto y dependencias
    await _db.deleteProductCascade(p.id!);

    if (!mounted) return;
    setState(() => _depleted.remove(p));

    // ✅ 3️⃣ Muestra confirmación segura
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Producto "${p.name}" eliminado completamente'),
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos Agotados')),
      body: _depleted.isEmpty
          ? const Center(child: Text('No hay productos agotados'))
          : ListView.builder(
        itemCount: _depleted.length,
        itemBuilder: (context, i) {
          final p = _depleted[i];
          final date = DateTime.tryParse(p.depletedAt ?? '');
          final formatted = date != null
              ? '${date.day}/${date.month}/${date.year}'
              : '';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: p.imagePath != null && File(p.imagePath!).existsSync()
                  ? Image.file(File(p.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                  : const Icon(Icons.image_not_supported),
              title: Text(p.name),
              subtitle: Text('Agotado el $formatted'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.folder_copy_outlined, color: Colors.grey),
                    tooltip: 'Ver historial',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductHistoryPage(
                            productId: p.id!,
                            productName: p.name,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.green),
                    tooltip: 'Reactivar producto',
                    onPressed: () => _reactivateProduct(p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    tooltip: 'Eliminar permanentemente',
                    onPressed: () => _confirmAndDeleteProduct(p),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _previewPdf,
        child: const Icon(Icons.picture_as_pdf_outlined),
      ),
    );
  }
}