import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/database_helper.dart';
import '../../models/style_settings.dart';

class CatalogStylePage extends StatefulWidget {
  const CatalogStylePage({super.key});

  @override
  State<CatalogStylePage> createState() => _CatalogStylePageState();
}

class _CatalogStylePageState extends State<CatalogStylePage> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  late StyleSettings _style;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    final bg = await _db.getSetting('style.backgroundColor');
    final hl = await _db.getSetting('style.highlightColor');
    final ib = await _db.getSetting('style.infoBoxColor');
    final tx = await _db.getSetting('style.textColor');
    final lg = await _db.getSetting('style.logoPath');

    if (!mounted) return;
    setState(() {
      _style = StyleSettings(
        backgroundColor: int.tryParse(bg ?? '') ?? 0xFFF4F7F8,
        highlightColor: int.tryParse(hl ?? '') ?? 0xFF3A8FB7,
        infoBoxColor: int.tryParse(ib ?? '') ?? 0xFFE6E1C5,
        textColor: int.tryParse(tx ?? '') ?? 0xFF222222,
        logoPath: lg,
      );
      _loading = false;
    });
  }

  Future<void> _saveStyle() async {
    await _db.setSetting('style.backgroundColor', _style.backgroundColor.toString());
    await _db.setSetting('style.highlightColor', _style.highlightColor.toString());
    await _db.setSetting('style.infoBoxColor', _style.infoBoxColor.toString());
    await _db.setSetting('style.textColor', _style.textColor.toString());
    if (_style.logoPath != null) {
      await _db.setSetting('style.logoPath', _style.logoPath!);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Estilo guardado')));
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _style = StyleSettings.defaults();
    });
    await _saveStyle();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Colores restaurados a los valores predeterminados')));
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    try {
      final appDir = await getApplicationSupportDirectory();
      final logoDir = Directory('${appDir.path}/logos');
      if (!await logoDir.exists()) await logoDir.create(recursive: true);
      final fileName = xfile.name;
      final newPath = '${logoDir.path}/$fileName';
      final newFile = await File(xfile.path).copy(newPath);
      if (!mounted) return;
      setState(() => _style = _style.copyWith(logoPath: newFile.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error copiando logo: $e')));
    }
  }

  void _pickColor(String label, int currentColor, Function(Color) onChanged) {
    final colorController =
    TextEditingController(text: '#${currentColor.toRadixString(16).padLeft(8, '0').toUpperCase()}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Selecciona color: $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
              pickerColor: Color(currentColor),
              onColorChanged: (c) {
                onChanged(c);
                colorController.text =
                '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
              },
              enableAlpha: false,
              labelTypes: const [],
              pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: colorController,
              decoration: const InputDecoration(
                labelText: 'Código de color (ej. #3A8FB7 o 0xFF3A8FB7)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                try {
                  var hex = value.trim();
                  if (hex.startsWith('#')) {
                    hex = hex.replaceFirst('#', '0xFF');
                  }
                  final colorValue = int.parse(hex);
                  onChanged(Color(colorValue));
                  setState(() {}); // actualizar vista
                } catch (_) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Código de color inválido')));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estilo del Catálogo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Estilo del Catálogo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // 🖼️ Vista previa del logo actual
            if (_style.logoPath != null && File(_style.logoPath!).existsSync())
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Logo actual:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Image.file(File(_style.logoPath!), height: 80),
                  const SizedBox(height: 16),
                ],
              ),

            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Seleccionar logo'),
              subtitle: Text(_style.logoPath != null
                  ? 'Logo personalizado'
                  : 'Sin logo'),
              trailing: IconButton(
                icon: const Icon(Icons.upload),
                onPressed: _pickLogo,
              ),
            ),
            const Divider(),
            _colorSelector('Fondo', _style.backgroundColor,
                    (c) => setState(() => _style = _style.copyWith(backgroundColor: c.toARGB32()))),
            _colorSelector('Destacado', _style.highlightColor,
                    (c) => setState(() => _style = _style.copyWith(highlightColor: c.toARGB32()))),
            _colorSelector('Caja de información', _style.infoBoxColor,
                    (c) => setState(() => _style = _style.copyWith(infoBoxColor: c.toARGB32()))),
            _colorSelector('Texto', _style.textColor,
                    (c) => setState(() => _style = _style.copyWith(textColor: c.toARGB32()))),
            const SizedBox(height: 24),

            // 💾 Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveStyle,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar colores'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSelector(String label, int color, Function(Color) onChanged) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(color),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.colorize),
            onPressed: () => _pickColor(label, color, onChanged),
          ),
        ],
      ),
    );
  }
}
