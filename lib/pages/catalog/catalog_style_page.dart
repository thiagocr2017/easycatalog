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
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadStyle();
    _loadPayments();
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
        backgroundColor: int.tryParse(bg ?? '') ?? 0xFFE1F6B4,
        highlightColor: int.tryParse(hl ?? '') ?? 0xFF50B203,
        infoBoxColor: int.tryParse(ib ?? '') ?? 0xFFEEE9CC,
        textColor: int.tryParse(tx ?? '') ?? 0xFF222222,
        logoPath: lg,
      );
      _loading = false;
    });
  }

  Future<void> _loadPayments() async {
    final data = await _db.getPaymentMethods();
    if (!mounted) return;
    setState(() => _payments = data);
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
        .showSnackBar(const SnackBar(content: Text('Estilo guardado correctamente')));
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _style = const StyleSettings(
        backgroundColor: 0xFFE1F6B4,
        highlightColor: 0xFF50B203,
        infoBoxColor: 0xFFEEE9CC,
        textColor: 0xFF222222,
      );
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

    final appDir = await getApplicationSupportDirectory();
    final logoDir = Directory('${appDir.path}/logos');
    if (!await logoDir.exists()) await logoDir.create(recursive: true);
    final fileName = xfile.name;
    final newPath = '${logoDir.path}/$fileName';
    final newFile = await File(xfile.path).copy(newPath);

    if (!mounted) return;
    setState(() => _style = _style.copyWith(logoPath: newFile.path));
  }

  Future<void> _addOrEditPayment({Map<String, dynamic>? payment}) async {
    final nameCtrl = TextEditingController(text: (payment?['name'] ?? '').toString());
    final infoCtrl = TextEditingController(text: (payment?['info'] ?? '').toString());
    final beneficiaryCtrl = TextEditingController(text: (payment?['beneficiary'] ?? '').toString());
    String? logoPath = payment?['logoPath'];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(payment == null ? 'Nuevo método de pago' : 'Editar método de pago'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del método')),
              TextField(controller: infoCtrl, decoration: const InputDecoration(labelText: 'Información (cuenta, IBAN, etc.)')),
              TextField(controller: beneficiaryCtrl, decoration: const InputDecoration(labelText: 'Beneficiario')),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final xfile = await picker.pickImage(source: ImageSource.gallery);
                  if (xfile == null) return;

                  final appDir = await getApplicationSupportDirectory();
                  final logosDir = Directory('${appDir.path}/logos');
                  if (!await logosDir.exists()) await logosDir.create(recursive: true);
                  final newPath = '${logosDir.path}/${xfile.name}';
                  final newFile = await File(xfile.path).copy(newPath);
                  logoPath = newFile.path;
                  setState(() {}); // refrescar el diálogo
                },
                icon: const Icon(Icons.image_outlined),
                label: Text(logoPath != null ? 'Logo seleccionado' : 'Seleccionar logo'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'id': payment?['id'],
                'name': nameCtrl.text.trim(),
                'info': infoCtrl.text.trim(),
                'beneficiary': beneficiaryCtrl.text.trim(),
                'logoPath': logoPath,
              };

              if (payment == null) {
                await _db.insertPaymentMethod(data);
              } else {
                await _db.updatePaymentMethod(data);
              }

              if (!mounted) return;
              Navigator.pop(context);
              _loadPayments();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePayment(int id) async {
    await _db.deletePaymentMethod(id);
    _loadPayments();
  }

  void _pickColor(String label, int currentColor, Function(Color) onChanged) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Selecciona color: $label'),
        content: BlockPicker(
          pickerColor: Color(currentColor),
          onColorChanged: (c) => onChanged(c),
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
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Seleccionar logo principal'),
              subtitle: Text(_style.logoPath ?? 'Sin logo'),
              onTap: _pickLogo,
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

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveStyle,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar estilo'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _resetToDefault,
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar colores predeterminados'),
            ),
            const SizedBox(height: 20),

            // 🔹 Métodos de pago
            const Text('Métodos de pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            ..._payments.map((p) => Card(
              child: ListTile(
                title: Text(p['name'] ?? 'Sin nombre'),
                subtitle: Text('${p['info'] ?? ''}\n${p['beneficiary'] ?? ''}'),
                leading: p['logoPath'] != null && File(p['logoPath']).existsSync()
                    ? Image.file(File(p['logoPath']), width: 40, height: 40, fit: BoxFit.cover)
                    : const Icon(Icons.account_balance_wallet),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEditPayment(payment: p)),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () => _deletePayment(p['id'])),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _addOrEditPayment(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar método de pago'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSelector(String label, int color, Function(Color) onChanged) {
    return ListTile(
      title: Text(label),
      trailing: GestureDetector(
        onTap: () => _pickColor(label, color, onChanged),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Color(color),
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
