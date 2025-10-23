import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../data/database_helper.dart';
import '../../../models/product.dart';
import '../../../models/section.dart';
import '../../../models/product_image_setting.dart';
import '../../../widgets/product_image_preview.dart';

class ProductFormPage extends StatefulWidget {
  final Product? product;
  final List<Section> sections;
  final VoidCallback onSave;

  const ProductFormPage({
    super.key,
    this.product,
    required this.sections,
    required this.onSave,
  });

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _db = DatabaseHelper.instance;

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  Section? _selectedSection;
  String? _imagePath;

  double _zoom = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
    _priceCtrl = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _selectedSection = widget.sections.firstWhere(
          (s) => s.id == widget.product?.sectionId,
      orElse: () =>
      widget.sections.isNotEmpty ? widget.sections.first : Section(name: ''),
    );
    _imagePath = widget.product?.imagePath;
    _loadImageSettings();
  }

  Future<void> _loadImageSettings() async {
    if (widget.product?.id != null) {
      final conf = await _db.getImageSetting(widget.product!.id!);
      if (conf != null) {
        setState(() {
          _zoom = conf.zoom;
          _offsetX = conf.offsetX;
          _offsetY = conf.offsetY;
        });
      }
    }
  }

  // 📸 Seleccionar imagen (mantiene archivo original + optimiza peso)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    String cleanName = _nameCtrl.text.trim().toLowerCase();
    if (cleanName.isEmpty) {
      cleanName = 'producto_${DateTime.now().millisecondsSinceEpoch}';
    }
    cleanName = cleanName.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    const ext = 'jpg';

    final appDir = await getApplicationSupportDirectory();
    final imagesDir = Directory('${appDir.path}/images');
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

    final newPath = '${imagesDir.path}/$cleanName.$ext';

    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        xfile.path,
        minHeight: 1200,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes != null) {
        final newFile = await File(newPath).writeAsBytes(compressedBytes);
        setState(() => _imagePath = newFile.path);

        // Limpiar cache para forzar recarga
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imagen optimizada guardada como "$cleanName.jpg"')),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al comprimir imagen: $e');
    }
  }

  // 💾 Guardar producto
  Future<void> _saveProduct() async {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    final sectionId = _selectedSection?.id;

    if (name.isEmpty || sectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos obligatorios')),
      );
      return;
    }

    final data = Product(
      id: widget.product?.id,
      name: name,
      description: desc,
      price: price,
      sectionId: sectionId,
      imagePath: _imagePath,
      sortOrder: widget.product?.sortOrder ?? 0,
    ).toMap();

    int productId;
    if (widget.product == null) {
      productId = await _db.insertProduct(data);
    } else {
      await _db.updateProduct(data);
      productId = widget.product!.id!;
    }

    await _db.upsertImageSetting(ProductImageSetting(
      productId: productId,
      zoom: _zoom,
      offsetX: _offsetX,
      offsetY: _offsetY,
    ));

    widget.onSave();
    if (!mounted) return;
    Navigator.pop(context);
  }

  // 🧱 INTERFAZ
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Nuevo producto' : 'Editar producto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Section>(
              initialValue: _selectedSection,
              items: widget.sections
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedSection = val),
              decoration: const InputDecoration(labelText: 'Sección'),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: Icon(
                    _imagePath != null ? Icons.check_circle : Icons.image_outlined),
                label: Text(_imagePath != null
                    ? 'Imagen seleccionada'
                    : 'Seleccionar imagen'),
              ),
            ),

            // 🖼️ Vista previa de imagen con proporción PDF
            if (_imagePath != null && File(_imagePath!).existsSync()) ...[
              const SizedBox(height: 20),
              Center(
                child: ProductImagePreview(
                  imagePath: _imagePath,
                  zoom: _zoom,
                  offsetX: _offsetX,
                  offsetY: _offsetY,
                  scaleFactor: 0.8, // 📏 80% del tamaño base PDF (180×260)
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ajustar imagen para PDF',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _zoom,
                min: 0.2,
                max: 5.0,
                divisions: 100,
                label: 'Zoom: ${_zoom.toStringAsFixed(2)}x',
                onChanged: (v) => setState(() => _zoom = v),
              ),
              Row(
                children: [
                  const Text('Desplazamiento X'),
                  Expanded(
                    child: Slider(
                      value: _offsetX,
                      min: -10.0,
                      max: 10.0,
                      divisions: 100,
                      onChanged: (v) => setState(() => _offsetX = v),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Desplazamiento Y'),
                  Expanded(
                    child: Slider(
                      value: _offsetY,
                      min: -10.0,
                      max: 10.0,
                      divisions: 100,
                      onChanged: (v) => setState(() => _offsetY = v),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _saveProduct,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
