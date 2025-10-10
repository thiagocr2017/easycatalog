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
  Map<int, String> _sectionNames = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sectionData = await _db.getSections();
    final productData = await _db.getProducts();

    final sections = sectionData.map((e) => Section.fromMap(e)).toList();
    final products = productData.map((e) => Product.fromMap(e)).toList();

    final sectionNames = {
      for (final s in sections) if (s.id != null) s.id!: s.name
    };

    if (!mounted) return;
    setState(() {
      _sections = sections;
      _products = products;
      _sectionNames = sectionNames;
    });
  }

  Future<void> _addOrEditProduct({Product? product}) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final priceCtrl = TextEditingController(text: product?.price.toString() ?? '');
    Section? selectedSection = _sections.firstWhere(
          (s) => s.id == product?.sectionId,
      orElse: () => _sections.isNotEmpty ? _sections.first : Section(name: ''),
    );
    String? imagePath = product?.imagePath;

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
                  decoration: const InputDecoration(labelText: 'Descripción')),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
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

                  final appDir = await getApplicationSupportDirectory();
                  final imagesDir = Directory('${appDir.path}/images');
                  if (!await imagesDir.exists()) {
                    await imagesDir.create(recursive: true);
                  }

                  final fileName = xfile.name;
                  final newPath = '${imagesDir.path}/$fileName';
                  final newFile = await File(xfile.path).copy(newPath);
                  imagePath = newFile.path;

                  if (!context.mounted) return;
                  (context as Element).markNeedsBuild();
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
              _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDepleted(Product p) async {
    final newState = !p.isDepleted;
    final updated = p.toMap();
    updated['isDepleted'] = newState ? 1 : 0;
    updated['depletedAt'] = newState ? DateTime.now().toIso8601String() : null;
    await _db.updateProduct(updated);
    await _db.insertProductLog(p.id!, newState ? 'agotado' : 'reactivado');

    if (!mounted) return;
    setState(() {
      p.isDepleted = newState;
      p.depletedAt =
      newState ? DateTime.now().toIso8601String() : null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState
            ? 'Producto "${p.name}" marcado como agotado'
            : 'Producto "${p.name}" reactivado'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      final sectionName =
          _sectionNames[p.sectionId ?? -1]?.toLowerCase() ?? 'sin sección';
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sectionName.contains(_searchQuery.toLowerCase());
    }).toList();

    final grouped = <String, List<Product>>{};
    for (final p in filteredProducts) {
      final name = _sectionNames[p.sectionId ?? -1] ?? 'Sin sección';
      grouped.putIfAbsent(name, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditProduct(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar producto o sección...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? const Center(child: Text('No hay productos registrados'))
                : ListView(
              children: grouped.entries.map((entry) {
                final sectionName = entry.key;
                final products = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.blueGrey.shade50,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        sectionName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                    ...products.map((p) => Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: p.imagePath != null &&
                            File(p.imagePath!).existsSync()
                            ? Image.file(File(p.imagePath!),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover)
                            : const Icon(Icons.image_not_supported),
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
                              tooltip: p.isDepleted
                                  ? 'Marcar como disponible'
                                  : 'Marcar como agotado',
                              onPressed: () => _toggleDepleted(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _addOrEditProduct(product: p),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
