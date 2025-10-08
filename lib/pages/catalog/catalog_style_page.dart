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

  void _pickColor(String label, Color current, Function(Color) onChanged) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Selecciona color: $label'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: onChanged,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
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
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Logo del catálogo'),
              subtitle: Text(
                _style.logoPath != null ? 'Logo personalizado' : 'Sin logo',
              ),
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
            ElevatedButton.icon(
              onPressed: _saveStyle,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSelector(String label, int color, Function(Color) onChanged) {
    return ListTile(
      title: Text(label),
      trailing: CircleAvatar(backgroundColor: Color(color)),
      onTap: () => _pickColor(label, Color(color), onChanged),
    );
  }
}
