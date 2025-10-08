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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sectionData = await _db.getSections();
    final productData = await _db.getProducts();
    if (!mounted) return;
    setState(() {
      _sections = sectionData.map((e) => Section.fromMap(e)).toList();
      _products = productData.map((e) => Product.fromMap(e)).toList();
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
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Section>(
                initialValue: selectedSection,
                items: _sections.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.name));
                }).toList(),
                onChanged: (val) => selectedSection = val,
                decoration: const InputDecoration(labelText: 'Sección'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(source: ImageSource.gallery);
                  if (xfile == null) return;

                  final appDir = await getApplicationSupportDirectory();
                  final imagesDir = Directory('${appDir.path}/images');
                  if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

                  final fileName = xfile.name;
                  final newPath = '${imagesDir.path}/$fileName';
                  final newFile = await File(xfile.path).copy(newPath);
                  imagePath = newFile.path;

                  if (!context.mounted) return;
                  setState(() {});
                },
                icon: const Icon(Icons.image),
                label: const Text('Seleccionar imagen'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
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
              messenger.showSnackBar(
                SnackBar(content: Text(product == null ? 'Producto agregado' : 'Producto actualizado')),
              );
              _loadData();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Estás seguro de eliminar "$name"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteProduct(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Producto "$name" eliminado')));
      _loadData();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditProduct(),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, i) {
          final p = _products[i];
          return ListTile(
            leading: p.imagePath != null && File(p.imagePath!).existsSync()
                ? Image.file(File(p.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported),
            title: Text(p.name),
            subtitle: Text('Precio: \$${p.price.toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    p.isDepleted ? Icons.visibility_off : Icons.visibility,
                    color: p.isDepleted ? Colors.red : Colors.green,
                  ),
                  tooltip: p.isDepleted ? 'Marcar como disponible' : 'Marcar como agotado',
                  onPressed: () async {
                    final updated = p.toMap();
                    updated['isDepleted'] = p.isDepleted ? 0 : 1;
                    updated['depletedAt'] = p.isDepleted
                        ? null
                        : DateTime.now().toIso8601String();
                    await _db.updateProduct(updated);
                    if (!mounted) return;
                    _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _addOrEditProduct(product: p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteProduct(p.id!, p.name),
                ),
              ],
            ),

          );
        },
      ),
    );
  }
}
