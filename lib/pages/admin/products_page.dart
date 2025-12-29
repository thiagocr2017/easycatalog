import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/product.dart';
import '../../models/section.dart';
import '../catalog/product_form_page.dart';

// =========== INICIO DE CAMBIO ESTRUCTURAL: DELEGADO PARA HEADER PEGADIZO ===========
class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_SliverHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
// =========== FIN DE CAMBIO ESTRUCTURAL ===========

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _db = DatabaseHelper.instance;
  final Map<int?, bool> _expandedSections = {};

  int? _editingSectionId;
  final List<int> _selectedProductIds = [];

  List<Product> _products = [];
  List<Section> _sections = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- MÉTODOS DE DATOS Y ACCIONES BÁSICAS (SIN CAMBIOS) ---
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

  List<Product> get _filteredProducts {
    final q = _searchQuery.toLowerCase();
    return _products.where((p) {
      final match = p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q);
      return match;
    }).toList();
  }

  Future<void> _openProductForm({Product? product}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormPage(product: product, sections: _sections, onSave: _loadData)));
    _loadData();
  }

  Future<void> _toggleActive(Product p) async {
    final newState = !p.isActive;
    final updated = p.toMap();
    updated['isActive'] = newState ? 1 : 0;
    await _db.updateProduct(updated);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Producto "${p.name}" ${newState ? 'activado' : 'desactivado'}'), backgroundColor: newState ? Colors.green.shade600 : Colors.orange.shade600));
  }

  Future<void> _toggleDepleted(Product p) async {
    final newState = !p.isDepleted;
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(newState ? 'Marcar como agotado' : 'Reactivar producto'), content: Text('¿Seguro que deseas ${newState ? 'agotar' : 'reactivar'} "${p.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, continuar'))]));
    if (confirm != true) return;
    final updated = p.toMap();
    updated['isDepleted'] = newState ? 1 : 0;
    updated['depletedAt'] = newState ? DateTime.now().toIso8601String() : null;
    await _db.updateProduct(updated);
    await _db.insertProductLog(p.id!, newState ? 'agotado' : 'reactivado');
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Producto "${p.name}" ${newState ? 'agotado' : 'reactivado'}'), backgroundColor: newState ? Colors.red.shade400 : Colors.green.shade600));
  }

  Future<File?> _resolveProductImage(Product p) async => await _db.resolveImageFile(p.imagePath);

  // --- LÓGICA DE REORDENAMIENTO (SIN CAMBIOS) ---

  void _toggleProductSelection(int productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _exitEditingMode() {
    setState(() {
      _editingSectionId = null;
      _selectedProductIds.clear();
    });
  }

  Future<void> _reorderProducts({
    required Product referenceProduct,
    required bool moveBefore,
  }) async {
    List<Product> allProducts = List.from(_products);

    final List<Product> productsToMove = [];
    allProducts.removeWhere((p) {
      if (_selectedProductIds.contains(p.id)) {
        productsToMove.add(p);
        return true;
      }
      return false;
    });

    int referenceIndex = allProducts.indexWhere((p) => p.id == referenceProduct.id);
    if (referenceIndex == -1) return;

    int insertionIndex = moveBefore ? referenceIndex : referenceIndex + 1;

    allProducts.insertAll(insertionIndex, productsToMove);

    for (int i = 0; i < allProducts.length; i++) {
      allProducts[i].sortOrder = i;
    }

    await _db.batchUpdateProducts(allProducts.map((p) => p.toMap()).toList());

    _exitEditingMode();
    _loadData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Productos reordenados con éxito.'), backgroundColor: Colors.green),
    );
  }

  Future<Product?> _showReferenceProductPicker(List<Product> availableTargets) async {
    return await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Seleccionar Producto de Referencia', style: Theme.of(context).textTheme.titleLarge),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: availableTargets.length,
                    itemBuilder: (context, index) {
                      final p = availableTargets[index];
                      return ListTile(
                        leading: FutureBuilder<File?>(
                          future: _resolveProductImage(p),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.file(snapshot.data!, width: 50, height: 50, fit: BoxFit.cover);
                            }
                            return const Icon(Icons.image_not_supported, size: 40);
                          },
                        ),
                        title: Text(p.name),
                        subtitle: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMoveProductsDialog(List<Product> productsInSection) async {
    final availableTargets = productsInSection.where((p) => !_selectedProductIds.contains(p.id)).toList();
    if (availableTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay productos de destino disponibles.')));
      return;
    }

    Product? referenceProduct = await _showReferenceProductPicker(availableTargets);
    if (referenceProduct == null || !mounted) return;

    bool moveBefore = true;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Mover ${_selectedProductIds.length} producto(s)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Posición relativa a:', style: Theme.of(context).textTheme.labelMedium),
                  Card(
                    child: ListTile(
                      title: Text(referenceProduct.name),
                      subtitle: Text(referenceProduct.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Radio<bool>(value: true, groupValue: moveBefore, onChanged: (v) => setDialogState(() => moveBefore = v!)),
                      const Text('Antes de'),
                    ],
                  ),
                  Row(
                    children: [
                      Radio<bool>(value: false, groupValue: moveBefore, onChanged: (v) => setDialogState(() => moveBefore = v!)),
                      const Text('Después de'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _reorderProducts(referenceProduct: referenceProduct, moveBefore: moveBefore);
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- UI PRINCIPAL (CON STICKY HEADERS) ---
  @override
  Widget build(BuildContext context) {
    final grouped = <int?, List<Product>>{};
    for (final p in _filteredProducts) {
      grouped.putIfAbsent(p.sectionId, () => []).add(p);
    }
    final orderedSections = _sections..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    final bool isEditingAnySection = _editingSectionId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: isEditingAnySection ? null : FloatingActionButton(onPressed: () => _openProductForm(), child: const Icon(Icons.add)),
      bottomNavigationBar: isEditingAnySection && _selectedProductIds.isNotEmpty
          ? BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.unfold_more_rounded),
            label: Text('Mover ${_selectedProductIds.length} producto(s)'),
            onPressed: () {
              final productsInSection = grouped[_editingSectionId] ?? [];
              _showMoveProductsDialog(productsInSection);
            },
          ),
        ),
      )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Buscar producto o descripción...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onChanged: (value) => setState(() => _searchQuery = value)),
            ),
          ),
          if (orderedSections.isEmpty)
            const SliverFillRemaining(child: Center(child: Text('No hay secciones definidas')))
          else
          // =========== INICIO DE CAMBIO ESTRUCTURAL: GENERAR SLIVERS POR SECCIÓN ===========
            ...orderedSections.expand((s) {
              final products = grouped[s.id] ?? [];
              if (products.isEmpty && _editingSectionId != s.id) return <Widget>[];

              final isExpanded = _expandedSections[s.id] ?? true;
              final bool isEditingThisSection = _editingSectionId == s.id;

              // Widget del encabezado de la sección
              final header = Container(
                color: isEditingThisSection ? Colors.blue.shade50 : Colors.green.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text('${s.name} (${products.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isEditingThisSection ? Colors.blue.shade800 : Colors.green))),
                    if (isEditingThisSection)
                      TextButton.icon(icon: const Icon(Icons.cancel), label: const Text("Salir"), onPressed: _exitEditingMode)
                    else
                      IconButton(icon: const Icon(Icons.sort, color: Colors.black54), tooltip: "Editar orden", onPressed: () => setState(() => _editingSectionId = s.id)),
                    IconButton(icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: isEditingThisSection ? Colors.blue.shade700 : Colors.green.shade700), onPressed: () => setState(() => _expandedSections[s.id] = !isExpanded)),
                  ],
                ),
              );

              return [
                // 1. El encabezado ahora es un Sliver pegajoso
                SliverPersistentHeader(
                  pinned: true, // Esto hace que se quede pegado
                  delegate: _SliverHeaderDelegate(
                    height: 64.0, // Altura del encabezado
                    child: header,
                  ),
                ),

                // 2. La lista de productos es un Sliver separado
                if (isExpanded)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final p = products[index];
                        return FutureBuilder<File?>(
                          key: ValueKey(p.id),
                          future: _resolveProductImage(p),
                          builder: (context, snapshot) {
                            final file = snapshot.data;

                            if (isEditingThisSection) {
                              final isSelected = _selectedProductIds.contains(p.id);
                              return Card(
                                color: isSelected ? Colors.blue.shade100 : null,
                                elevation: isSelected ? 4 : 1,
                                margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                child: ListTile(
                                  leading: Checkbox(value: isSelected, onChanged: (_) => _toggleProductSelection(p.id!)),
                                  title: Row(
                                    children: [
                                      file != null && file.existsSync()
                                          ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4.0),
                                        child: Image.file(file, width: 40, height: 40, fit: BoxFit.cover),
                                      )
                                          : const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    p.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  onTap: () => _toggleProductSelection(p.id!),
                                ),
                              );
                            } else {
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
                                color: Colors.grey.shade900,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      if (file != null && file.existsSync()) Image.file(file, width: 70, height: 100, fit: BoxFit.cover) else const Icon(Icons.image_not_supported, color: Colors.white70, size: 40),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white), overflow: TextOverflow.ellipsis),
                                            Text(p.description, style: TextStyle(fontSize: 13, color: Colors.grey.shade400), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text('Precio: \$${p.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: Colors.grey.shade300)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(icon: Icon(p.isActive ? Icons.toggle_on : Icons.toggle_off, color: p.isActive ? Colors.green : Colors.orange, size: 28), tooltip: p.isActive ? 'Desactivar producto' : 'Activar producto', onPressed: () => _toggleActive(p)),
                                          IconButton(icon: Icon(p.isDepleted ? Icons.visibility_off : Icons.visibility, color: p.isDepleted ? Colors.red : Colors.green), onPressed: () => _toggleDepleted(p)),
                                          IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _openProductForm(product: p)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
              ];
            }).toList(),
          // =========== FIN DE CAMBIO ESTRUCTURAL ===========
        ],
      ),
    );
  }
}
