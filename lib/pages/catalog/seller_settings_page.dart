import 'package:flutter/material.dart';
import '../../data/database_helper.dart';

class SellerSettingsPage extends StatefulWidget {
  const SellerSettingsPage({super.key});

  @override
  State<SellerSettingsPage> createState() => _SellerSettingsPageState();
}

class _SellerSettingsPageState extends State<SellerSettingsPage> {
  final _db = DatabaseHelper.instance;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _db.getSetting('seller.name');
    final phone = await _db.getSetting('seller.phone');
    final msg = await _db.getSetting('seller.message');
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = name ?? 'Thiago Lopez';
      _phoneCtrl.text = phone ?? '+52 55 1234 5678';
      _msgCtrl.text = msg ?? 'Hola Thiago, me gustaría hacer un pedido.';
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _db.setSetting('seller.name', _nameCtrl.text.trim());
    await _db.setSetting('seller.phone', _phoneCtrl.text.trim());
    await _db.setSetting('seller.message', _msgCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Datos guardados')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración del vendedor')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración del vendedor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del vendedor')),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mensaje de WhatsApp'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
