import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/database_helper.dart';
import '../../models/product.dart';
import '../../models/section.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _db = DatabaseHelper.instance;
  List<Product> _products = [];
  List<Section> _sections = [];
  //Map<int, String> _sectionNames = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ─────────────────────────────────────────────
  // CARGA INICIAL DE PRODUCTOS Y SECCIONES
  // ─────────────────────────────────────────────
  Future<void> _loadData() async {
    await _db.ensureProductSortOrderColumn();
    final sectionData = await _db.getSections();
    final productData = await _db.getProducts();

    final sections = sectionData.map((e) => Section.fromMap(e)).toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    final products = productData.map((e) => Product.fromMap(e)).toList();

    /*final sectionNames = {
      for (final s in sections) if (s.id != null) s.id!: s.name
    };*/

    if (!mounted) return;
    setState(() {
      _sections = sections;
      _products = products..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      //_sectionNames = sectionNames;
    });
  }

  // ─────────────────────────────────────────────
  // FILTRO DE BÚSQUEDA (NOMBRE + DESCRIPCIÓN)
  // ─────────────────────────────────────────────
  List<Product> get _filteredProducts {
    final q = _searchQuery.toLowerCase();
    return _products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
    }).toList();
  }

  // ─────────────────────────────────────────────
  // AGREGAR O EDITAR PRODUCTO
  // ─────────────────────────────────────────────
  Future<void> _addOrEditProduct({Product? product}) async {
    final messenger = ScaffoldMessenger.of(context);

    // 🔹 Recargamos secciones actualizadas y ordenadas
    final sectionData = await _db.getSections();
    final orderedSections = sectionData.map((e) => Section.fromMap(e)).toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    setState(() => _sections = orderedSections);

    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final priceCtrl =
    TextEditingController(text: product?.price.toString() ?? '');
    Section? selectedSection = _sections.firstWhere(
          (s) => s.id == product?.sectionId,
      orElse: () => _sections.isNotEmpty ? _sections.first : Section(name: ''),
    );
    String? imagePath = product?.imagePath;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? 'Nuevo producto' : 'Editar producto'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(
                  controller: descCtrl,
                  decoration:
                  const InputDecoration(labelText: 'Descripción')),
              TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Precio')),
              const SizedBox(height: 10),
              DropdownButtonFormField<Section>(
                initialValue: selectedSection,
                items: _sections
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (val) => selectedSection = val,
                decoration: const InputDecoration(labelText: 'Sección'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: imagePath != null
                      ? Colors.green.shade100
                      : Theme.of(context).primaryColor,
                  foregroundColor: imagePath != null
                      ? Colors.green.shade800
                      : Colors.white,
                ),
                onPressed: () async {
                  final picker = ImagePicker();
                  final xfile =
                  await picker.pickImage(source: ImageSource.gallery);
                  if (xfile == null) return;

                  String cleanName = nameCtrl.text.trim().toLowerCase();
                  if (cleanName.isEmpty) {
                    cleanName =
                    'producto_${DateTime.now().millisecondsSinceEpoch}';
                  }
                  cleanName =
                      cleanName.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                  final ext = xfile.name.split('.').last;

                  final appDir = await getApplicationSupportDirectory();
                  final imagesDir = Directory('${appDir.path}/images');
                  if (!await imagesDir.exists()) {
                    await imagesDir.create(recursive: true);
                  }
                  final newPath = '${imagesDir.path}/$cleanName.$ext';
                  final newFile = await File(xfile.path).copy(newPath);
                  imagePath = newFile.path;

                  if (!context.mounted) return;
                  (context as Element).markNeedsBuild();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                      Text('Imagen guardada como "$cleanName.$ext"')));
                },
                icon: Icon(imagePath != null
                    ? Icons.check_circle_outline
                    : Icons.image_outlined),
                label: Text(imagePath != null
                    ? 'Imagen seleccionada'
                    : 'Seleccionar imagen'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final desc = descCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0;
              final sectionId = selectedSection?.id;

              if (name.isEmpty || sectionId == null) return;

              final data = Product(
                id: product?.id,
                name: name,
                description: desc,
                price: price,
                sectionId: sectionId,
                imagePath: imagePath,
                sortOrder: product?.sortOrder ?? _products.length,
              ).toMap();

              if (product == null) {
                await _db.insertProduct(data);
              } else {
                await _db.updateProduct(data);
              }

              if (!context.mounted) return;
              Navigator.pop(context);
              messenger.showSnackBar(SnackBar(
                  content: Text(product == null
                      ? 'Producto agregado'
                      : 'Producto actualizado')));
              await _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CAMBIAR ESTADO (AGOTAR / REACTIVAR)
  // ─────────────────────────────────────────────
  Future<void> _toggleDepleted(Product p) async {
    final newState = !p.isDepleted;
    final actionText = newState ? 'agotar' : 'reactivar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newState ? 'Marcar como agotado' : 'Reactivar producto'),
        content:
        Text('¿Seguro que deseas $actionText el producto "${p.name}"?'),
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
  // REORDENAR PRODUCTOS (DRAG & DROP)
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
        if (p.id != null) {
          await _db.updateProduct(p.toMap());
        }
      }
      await _loadData();
    });
  }

  // ─────────────────────────────────────────────
  // UI PRINCIPAL (AGRUPADO POR SECCIÓN ORDENADA)
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
          onPressed: () => _addOrEditProduct(),
          child: const Icon(Icons.add),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
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
            Expanded(
              child: orderedSections.isEmpty
                  ? const Center(child: Text('No hay secciones definidas'))
                  : ListView(
                children: [
                  for (final s in orderedSections)
                    if (grouped[s.id]?.isNotEmpty ?? false)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            color: Colors.green.shade50,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              '${s.name} (${grouped[s.id]!.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics:
                            const NeverScrollableScrollPhysics(),
                            itemCount: grouped[s.id]!.length,
                            onReorder: (oldIndex, newIndex) =>
                                _onReorder(grouped[s.id]!,
                                    oldIndex, newIndex),
                            itemBuilder: (context, i) {
                              final p = grouped[s.id]![i];
                              return Card(
                                key: ValueKey(p.id ?? p.name),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: p.imagePath != null &&
                                      File(p.imagePath!)
                                          .existsSync()
                                      ? Image.file(
                                    File(p.imagePath!),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                      : const Icon(Icons
                                      .image_not_supported),
                                  title: Text(p.name),
                                  subtitle: Text(
                                      'Precio: \$${p.price.toStringAsFixed(2)}'),
                                  trailing: Row(
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
                                        /*tooltip: p.isDepleted
                                            ? 'Marcar como disponible'
                                            : 'Marcar como agotado',*/
                                        onPressed: () =>
                                            _toggleDepleted(p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () =>
                                            _addOrEditProduct(
                                                product: p),
                                      ),
                                      const Icon(Icons.drag_handle,
                                          color: Colors.grey),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
