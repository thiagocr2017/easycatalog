import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/product.dart';
import '../../models/product_image_setting.dart';
import '../../models/section.dart';
import '../catalog/product_form_page.dart';
import '../../widgets/product_image_preview.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _db = DatabaseHelper.instance;
  final Map<int?, bool> _expandedSections = {}; // Estado de visibilidad por sección

  List<Product> _products = [];
  List<Section> _sections = [];
  Map<int, ProductImageSetting?> _imageSettings = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─────────────────────────────────────────────
  // CARGA PRODUCTOS, SECCIONES Y CONFIGURACIONES
  // ─────────────────────────────────────────────
  Future<void> _loadData() async {
    await _db.ensureProductSortOrderColumn();
    final sectionData = await _db.getSections();
    final productData = await _db.getProducts();

    final sections = sectionData.map((e) => Section.fromMap(e)).toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    final products = productData.map((e) => Product.fromMap(e)).toList();
    final settings = await _db.getAllImageSettings();

    if (!mounted) return;
    setState(() {
      _sections = sections;
      _products = products..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _imageSettings = settings;

      // 🔹 Inicializa todas las secciones expandidas por defecto
      for (final s in sections) {
        _expandedSections[s.id] ??= true;
      }
    });
  }

  // ─────────────────────────────────────────────
  // FILTRO DE BÚSQUEDA
  // ─────────────────────────────────────────────
  List<Product> get _filteredProducts {
    final q = _searchQuery.toLowerCase();
    return _products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
    }).toList();
  }

  // ─────────────────────────────────────────────
  // ABRIR FORMULARIO (NUEVO / EDITAR)
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
  // CAMBIAR ESTADO (AGOTADO / ACTIVO)
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
      content: Text(
          'Producto "${p.name}" ${newState ? 'marcado como agotado' : 'reactivado'}'),
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

    Future.microtask(() async {
      for (final p in list) {
        if (p.id != null) await _db.updateProduct(p.toMap());
      }
      await _loadData();
    });
  }

  // ─────────────────────────────────────────────
  // INTERFAZ PRINCIPAL
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton(
          onPressed: () => _openProductForm(),
          child: const Icon(Icons.add),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
            // 🔍 Campo de búsqueda
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

            // 📋 Lista de secciones y productos
            Expanded(
              child: orderedSections.isEmpty
                  ? const Center(child: Text('No hay secciones definidas'))
                  : ListView.builder(
                itemCount: orderedSections.length,
                itemBuilder: (context, sectionIndex) {
                  final s = orderedSections[sectionIndex];
                  final products = grouped[s.id] ?? [];
                  if (products.isEmpty) return const SizedBox.shrink();

                  final isExpanded = _expandedSections[s.id] ?? true;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Encabezado de sección con botón de expandir/colapsar
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
                              onPressed: () {
                                setState(() {
                                  final current = _expandedSections[s.id] ?? true;
                                  _expandedSections[s.id] = !current; // ← alterna solo la actual
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // 🔸 Lista de productos (solo si está expandida)
                      if (isExpanded)
                        ReorderableListView(
                          key: PageStorageKey('section_${s.id}'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          onReorder: (o, n) =>
                              _onReorder(products, o, n),
                          children: [
                            for (final p in products)
                              Card(
                                key: ValueKey(p.id),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 13),
                                color: Colors.grey.shade900,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      // 🖼️ Imagen del producto
                                      ProductImagePreview(
                                        imagePath: p.imagePath,
                                        zoom: _imageSettings[p.id]?.zoom ??
                                            1.0,
                                        offsetX: _imageSettings[p.id]
                                            ?.offsetX ??
                                            0.0,
                                        offsetY: _imageSettings[p.id]
                                            ?.offsetY ??
                                            0.0,
                                        scaleFactor: 0.35,
                                      ),
                                      const SizedBox(width: 12),
                                      // 🧾 Información del producto
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              overflow:
                                              TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Precio: \$${p.price.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                Colors.grey.shade300,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // ⚙️ Botones de acción
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              p.isDepleted
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: p.isDepleted
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                            tooltip: p.isDepleted
                                                ? 'Producto agotado'
                                                : 'Activo',
                                            onPressed: () =>
                                                _toggleDepleted(p),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.white),
                                            tooltip: 'Editar producto',
                                            onPressed: () =>
                                                _openProductForm(
                                                    product: p),
                                          ),
                                          const Icon(Icons.drag_handle,
                                              color: Colors.grey),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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