import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int _currentSellerId = 1;
  List<int> _sellerIds = [];

  @override
  void initState() {
    super.initState();
    _loadSellerIds();
  }

  // 🔹 Cargar lista de vendedores y vendedor activo guardado
  Future<void> _loadSellerIds() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt('activeSellerId');
    final ids = await _db.getAllSellerIds();

    if (ids.isEmpty) {
      await _db.setSellerSetting(1, 'name', 'Thiago Lopez');
      await _db.setSellerSetting(1, 'phone', '+52 55 1234 5678');
      await _db.setSellerSetting(1, 'message', 'Hola Thiago, me gustaría hacer un pedido.');
      ids.add(1);
    }

    setState(() {
      _sellerIds = ids;
      _currentSellerId = savedId != null && ids.contains(savedId) ? savedId : ids.first;
    });

    _loadSeller(_currentSellerId);
  }

  Future<void> _loadSeller(int id) async {
    setState(() => _loading = true);
    final data = await _db.getSellerSettings(id);
    setState(() {
      _nameCtrl.text = data['name'] ?? 'Thiago Lopez';
      _phoneCtrl.text = data['phone'] ?? '+52 55 1234 5678';
      _msgCtrl.text = data['message'] ?? 'Hola Thiago, me gustaría hacer un pedido.';
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _db.setSellerSetting(_currentSellerId, 'name', _nameCtrl.text.trim());
    await _db.setSellerSetting(_currentSellerId, 'phone', _phoneCtrl.text.trim());
    await _db.setSellerSetting(_currentSellerId, 'message', _msgCtrl.text.trim());

    // 🔹 Guardar ID actual como “activo”
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('activeSellerId', _currentSellerId);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Datos guardados')));
  }

  Future<void> _addNewSeller() async {
    final newId = (_sellerIds.isEmpty ? 0 : _sellerIds.last) + 1;
    await _db.setSellerSetting(newId, 'name', 'Nuevo Vendedor $newId');
    await _db.setSellerSetting(newId, 'phone', '');
    await _db.setSellerSetting(newId, 'message', '');
    await _loadSellerIds();
    _loadSeller(newId);

    // Guardar nuevo como activo
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('activeSellerId', newId);
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
      appBar: AppBar(
        title: const Text('Configuración del vendedor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo vendedor',
            onPressed: _addNewSeller,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButton<int>(
              value: _currentSellerId,
              items: _sellerIds
                  .map((id) => DropdownMenuItem(
                value: id,
                child: Text('Vendedor $id'),
              ))
                  .toList(),
              onChanged: (id) async {
                if (id == null) return;
                setState(() => _currentSellerId = id);
                _loadSeller(id);

                // 🔹 Guardar vendedor seleccionado como activo
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('activeSellerId', id);
              },
            ),
            const SizedBox(height: 16),
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
