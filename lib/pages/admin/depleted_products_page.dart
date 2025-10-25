import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/product.dart';
import '../../services/depleted_report_service.dart';
import '../catalog/pdf_preview_page.dart';
import 'product_history_page.dart';

class DepletedProductsPage extends StatefulWidget {
  const DepletedProductsPage({super.key});

  @override
  State<DepletedProductsPage> createState() => _DepletedProductsPageState();
}

class _DepletedProductsPageState extends State<DepletedProductsPage> {
  final _db = DatabaseHelper.instance;
  final _reportService = DepletedReportService();

  List<Product> _allDepleted = [];
  List<Product> _filteredDepleted = [];
  String _searchQuery = '';
  List<Map<String, dynamic>> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadDepleted();
  }

  // ─────────────────────────────────────────────
  // Cargar productos agotados
  // ─────────────────────────────────────────────
  Future<void> _loadDepleted() async {
    final data = await _db.getProducts();
    final sections = await _db.getSections();

    final depleted = data
        .map((e) => Product.fromMap(e))
        .where((p) => p.isDepleted)
        .toList();

    if (!mounted) return;
    setState(() {
      _allDepleted = depleted;
      _filteredDepleted = depleted;
      _sections = sections;
    });
  }

  // ─────────────────────────────────────────────
  // Filtrar productos
  // ─────────────────────────────────────────────
  void _filterProducts(String query) {
    final q = query.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredDepleted = _allDepleted.where((p) {
        final nameMatch = p.name.toLowerCase().contains(q);
        final descMatch = p.description.toLowerCase().contains(q);
        final section = _sections.firstWhere(
              (s) => s['id'] == p.sectionId,
          orElse: () => {'name': ''},
        );
        final sectionMatch =
        (section['name'] as String).toLowerCase().contains(q);
        return nameMatch || descMatch || sectionMatch;
      }).toList();
    });
  }

  // ─────────────────────────────────────────────
  // Reactivar producto agotado
  // ─────────────────────────────────────────────
  Future<void> _reactivateProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reactivar producto'),
        content: Text('¿Deseas reactivar "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, reactivar'),
          ),
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
      _allDepleted.remove(p);
      _filteredDepleted.remove(p);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Producto "${p.name}" reactivado')),
    );
  }

  // ─────────────────────────────────────────────
  // Activar / desactivar producto
  // ─────────────────────────────────────────────
  Future<void> _toggleActive(Product p) async {
    final newState = !p.isActive;
    final updated = p.toMap();
    updated['isActive'] = newState ? 1 : 0;
    await _db.updateProduct(updated);
    await _loadDepleted();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Producto "${p.name}" ${newState ? 'activado' : 'desactivado'}',
      ),
      backgroundColor:
      newState ? Colors.green.shade600 : Colors.orange.shade600,
    ));
  }

  // ─────────────────────────────────────────────
  // Eliminar producto definitivamente
  // ─────────────────────────────────────────────
  Future<void> _confirmAndDeleteProduct(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que deseas eliminar "${p.name}"?\nEsta acción no se puede deshacer.',
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

    // Eliminar imagen física
    final file = await _db.resolveImageFile(p.imagePath);
    if (file != null && file.existsSync()) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('⚠️ No se pudo eliminar la imagen: $e');
      }
    }

    await _db.deleteProductCascade(p.id!);

    if (!mounted) return;
    setState(() {
      _allDepleted.remove(p);
      _filteredDepleted.remove(p);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Producto "${p.name}" eliminado completamente'),
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Generar PDF
  // ─────────────────────────────────────────────
  void _previewPdf() {
    if (_allDepleted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay productos agotados para generar reporte')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          customBuilder: (format) async =>
          await _reportService.buildDepletedProductsReport(_allDepleted),
          title: 'Reporte de productos agotados',
          fileName: 'productos_agotados.pdf',
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generando reporte de productos agotados...')),
    );
  }

  // ─────────────────────────────────────────────
  // Resolver imagen del producto
  // ─────────────────────────────────────────────
  Future<File?> _resolveProductImage(Product p) async {
    return await _db.resolveImageFile(p.imagePath);
  }

  // ─────────────────────────────────────────────
  // UI PRINCIPAL
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos Agotados')),
      body: Column(
        children: [
          // 🔍 Buscador
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por nombre, descripción o sección...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterProducts,
            ),
          ),

          // 📊 Contador
          if (_allDepleted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                width: double.infinity,
                color: Colors.green.shade50,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  _searchQuery.isEmpty
                      ? 'Mostrando ${_allDepleted.length} productos agotados'
                      : 'Mostrando ${_filteredDepleted.length} de ${_allDepleted.length} resultados para: "$_searchQuery"',
                  style: const TextStyle(fontSize: 13, color: Colors.green),
                ),
              ),
            ),

          // 📋 Lista
          Expanded(
            child: _filteredDepleted.isEmpty
                ? const Center(child: Text('No hay productos agotados'))
                : ListView.builder(
              itemCount: _filteredDepleted.length,
              itemBuilder: (context, i) {
                final p = _filteredDepleted[i];
                final date = DateTime.tryParse(p.depletedAt ?? '');
                final formatted = date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : '';

                return FutureBuilder<File?>(
                  future: _resolveProductImage(p),
                  builder: (context, snapshot) {
                    final file = snapshot.data;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: file != null && file.existsSync()
                            ? Image.file(
                          file,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                            : const Icon(Icons.image_not_supported),
                        title: Text(p.name),
                        subtitle: Text('Agotado el $formatted'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 📜 Historial
                            IconButton(
                              icon: const Icon(Icons.folder_copy_outlined,
                                  color: Colors.grey),
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

                            // 🔁 Reactivar
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye,
                                  color: Colors.green),
                              tooltip: 'Reactivar producto',
                              onPressed: () => _reactivateProduct(p),
                            ),

                            // ⚙️ Activar/desactivar
                            IconButton(
                              icon: Icon(
                                p.isActive
                                    ? Icons.toggle_on
                                    : Icons.toggle_off,
                                color: p.isActive
                                    ? Colors.green
                                    : Colors.orange,
                                size: 30,
                              ),
                              tooltip: p.isActive
                                  ? 'Desactivar producto'
                                  : 'Activar producto',
                              onPressed: () => _toggleActive(p),
                            ),

                            // 🗑️ Eliminar
                            IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: Colors.redAccent),
                              tooltip: 'Eliminar permanentemente',
                              onPressed: () =>
                                  _confirmAndDeleteProduct(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _previewPdf,
        child: const Icon(Icons.picture_as_pdf_outlined),
      ),
    );
  }
}
