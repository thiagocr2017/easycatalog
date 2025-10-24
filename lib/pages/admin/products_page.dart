import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/product.dart';
import '../../models/section.dart';
import '../catalog/product_form_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _db = DatabaseHelper.instance;
  final Map<int?, bool> _expandedSections = {}; // controla secciones abiertas/cerradas

  List<Product> _products = [];
  List<Section> _sections = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─────────────────────────────────────────────
  // CARGA PRODUCTOS Y SECCIONES
  // ─────────────────────────────────────────────
  Future<void> _loadData() async {
    await _db.ensureProductSortOrderColumn();
    final sectionData = await _db.getSections();
    final productData = await _db.getProducts();

    final sections = sectionData.map((e) => Section.fromMap(e)).toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    final products = productData.map((e) => Product.fromMap(e)).toList();

    if (!mounted) return;
    setState(() {
      _sections = sections;
      _products = products..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    });
  }

  // ─────────────────────────────────────────────
  // FILTRO DE BÚSQUEDA
  // ─────────────────────────────────────────────
  List<Product> get _filteredProducts {
    final q = _searchQuery.toLowerCase();
    return _products.where((p) {
      final match = p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
      return match;
    }).toList();
  }

  // ─────────────────────────────────────────────
  // ABRIR FORMULARIO NUEVO / EDITAR
  // ─────────────────────────────────────────────
  Future<void> _openProductForm({Product? product}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          product: product,
          sections: _sections,
          onSave: _loadData,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTIVAR / DESACTIVAR PRODUCTO
  // ─────────────────────────────────────────────
  Future<void> _toggleActive(Product p) async {
    final newState = !p.isActive;
    final updated = p.toMap();
    updated['isActive'] = newState ? 1 : 0;
    await _db.updateProduct(updated);
    await _loadData();

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
  // CAMBIAR ESTADO (AGOTADO / REACTIVAR)
  // ─────────────────────────────────────────────
  Future<void> _toggleDepleted(Product p) async {
    final newState = !p.isDepleted;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(newState ? 'Marcar como agotado' : 'Reactivar producto'),
        content: Text(
            '¿Seguro que deseas ${newState ? 'agotar' : 'reactivar'} "${p.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, continuar')),
        ],
      ),
    );

    if (confirm != true) return;

    final updated = p.toMap();
    updated['isDepleted'] = newState ? 1 : 0;
    updated['depletedAt'] =
    newState ? DateTime.now().toIso8601String() : null;
    await _db.updateProduct(updated);
    await _db.insertProductLog(p.id!, newState ? 'agotado' : 'reactivado');
    await _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Producto "${p.name}" ${newState ? 'agotado' : 'reactivado'}'),
      backgroundColor:
      newState ? Colors.red.shade400 : Colors.green.shade600,
    ));
  }

  // ─────────────────────────────────────────────
  // REORDENAR PRODUCTOS
  // ─────────────────────────────────────────────
  void _onReorder(List<Product> list, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });

    for (int i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
    }

    for (final p in list) {
      if (p.id != null) await _db.updateProduct(p.toMap());
    }
  }

  // ─────────────────────────────────────────────
  // RESOLVER IMAGEN DESDE RUTA RELATIVA O ABSOLUTA
  // ─────────────────────────────────────────────
  Future<File?> _resolveProductImage(Product p) async {
    return await _db.resolveImageFile(p.imagePath);
  }

  // ─────────────────────────────────────────────
  // UI PRINCIPAL
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final grouped = <int?, List<Product>>{};
    for (final p in _filteredProducts) {
      grouped.putIfAbsent(p.sectionId, () => []).add(p);
    }

    final orderedSections = _sections
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProductForm(),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
            // 🔍 Buscador
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar producto o descripción...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // 📋 Lista de secciones
            Expanded(
              child: orderedSections.isEmpty
                  ? const Center(child: Text('No hay secciones definidas'))
                  : ListView.builder(
                itemCount: orderedSections.length,
                itemBuilder: (context, sectionIndex) {
                  final s = orderedSections[sectionIndex];
                  final products = grouped[s.id] ?? [];
                  if (products.isEmpty) return const SizedBox.shrink();

                  final isExpanded = _expandedSections[s.id] ?? false;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🟩 Encabezado con expand/collapse
                      Container(
                        color: Colors.green.shade50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${s.name} (${products.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.green.shade700,
                              ),
                              onPressed: () => setState(() {
                                _expandedSections[s.id] = !isExpanded;
                              }),
                            ),
                          ],
                        ),
                      ),

                      // 🧾 Lista reordenable (solo visible si expandida)
                      if (isExpanded)
                        ReorderableListView(
                          key: PageStorageKey('section_${s.id}'),
                          shrinkWrap: true,
                          physics:
                          const NeverScrollableScrollPhysics(),
                          onReorder: (o, n) => _onReorder(products, o, n),
                          children: [
                            for (final p in products)
                              FutureBuilder<File?>(
                                key: ValueKey(p.id),
                                future: _resolveProductImage(p),
                                builder: (context, snapshot) {
                                  final file = snapshot.data;
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 13),
                                    color: Colors.grey.shade900,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                        children: [
                                          // 🖼️ Imagen
                                          if (file != null &&
                                              file.existsSync())
                                            Image.file(file,
                                                width: 70,
                                                height: 100,
                                                fit: BoxFit.cover)
                                          else
                                            const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.white70,
                                              size: 40,
                                            ),
                                          const SizedBox(width: 12),

                                          // 🧾 Texto
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                              children: [
                                                Text(
                                                  p.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                    FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                  overflow: TextOverflow
                                                      .ellipsis,
                                                ),
                                                Text(
                                                  'Precio: \$${p.price.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors
                                                        .grey.shade300,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // ⚙️ Botones de acción
                                          Row(
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  p.isActive
                                                      ? Icons.toggle_on
                                                      : Icons.toggle_off,
                                                  color: p.isActive
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  size: 28,
                                                ),
                                                tooltip: p.isActive
                                                    ? 'Desactivar producto'
                                                    : 'Activar producto',
                                                onPressed: () =>
                                                    _toggleActive(p),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  p.isDepleted
                                                      ? Icons
                                                      .visibility_off
                                                      : Icons.visibility,
                                                  color: p.isDepleted
                                                      ? Colors.red
                                                      : Colors.green,
                                                ),
                                                onPressed: () =>
                                                    _toggleDepleted(p),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.white),
                                                onPressed: () =>
                                                    _openProductForm(
                                                        product: p),
                                              ),
                                              // ☰ Drag & drop (separado con margen extra)
                                              const SizedBox(width: 15),
                                             // const Icon( Icons.drag_handle, color: Colors.grey),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}