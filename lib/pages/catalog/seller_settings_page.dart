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
  List<int> _sellerIds = [];
  int? _activeSellerId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSellers();
  }

  // ─────────────────────────────────────────────
  // Cargar vendedores
  // ─────────────────────────────────────────────
  Future<void> _loadSellers() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final ids = await _db.getAllSellerIds();
    final activeId = prefs.getInt('activeSellerId');

    if (!mounted) return;
    setState(() {
      _sellerIds = ids;
      _activeSellerId = activeId ?? (ids.isNotEmpty ? ids.first : null);
      _loading = false;
    });
  }

  // ─────────────────────────────────────────────
  // Obtener datos de vendedor
  // ─────────────────────────────────────────────
  Future<Map<String, String>> _getSellerData(int id) async {
    final data = await _db.getSellerSettings(id);
    return {
      'name': data['name'] ?? '',
      'phone': data['phone'] ?? '',
      'message': data['message'] ?? '',
    };
  }

  // ─────────────────────────────────────────────
  // Crear vendedor
  // ─────────────────────────────────────────────
  Future<void> _addSeller() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo vendedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Mensaje de WhatsApp')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final newId = (_sellerIds.isEmpty ? 0 : _sellerIds.last) + 1;
    await _db.setSellerSetting(newId, 'name', name);
    await _db.setSellerSetting(newId, 'phone', phoneCtrl.text.trim());
    await _db.setSellerSetting(newId, 'message', msgCtrl.text.trim());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('activeSellerId', newId);

    if (!mounted) return;
    await _loadSellers();
    _showSnack('Vendedor "$name" agregado');
  }

  // ─────────────────────────────────────────────
  // Editar vendedor
  // ─────────────────────────────────────────────
  Future<void> _editSeller(int id) async {
    final current = await _getSellerData(id);
    final nameCtrl = TextEditingController(text: current['name']);
    final phoneCtrl = TextEditingController(text: current['phone']);
    final msgCtrl = TextEditingController(text: current['message']);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar vendedor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: 'Mensaje de WhatsApp')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.setSellerSetting(id, 'name', nameCtrl.text.trim());
      await _db.setSellerSetting(id, 'phone', phoneCtrl.text.trim());
      await _db.setSellerSetting(id, 'message', msgCtrl.text.trim());
      if (!mounted) return;
      await _loadSellers();
      _showSnack('Vendedor actualizado');
    }
  }

  // ─────────────────────────────────────────────
  // Eliminar vendedor
  // ─────────────────────────────────────────────
  Future<void> _deleteSeller(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar vendedor'),
        content: const Text('¿Deseas eliminar este vendedor? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    final db = await _db.database;
    await db.delete('settings', where: 'key LIKE ?', whereArgs: ['seller.$id.%']);

    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('activeSellerId');
    if (activeId == id) await prefs.remove('activeSellerId');

    if (!mounted) return;
    await _loadSellers();
    _showSnack('Vendedor eliminado');
  }

  // ─────────────────────────────────────────────
  // Activar vendedor
  // ─────────────────────────────────────────────
  Future<void> _setActiveSeller(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('activeSellerId', id);
    if (!mounted) return;
    setState(() => _activeSellerId = id);
  }

  // ─────────────────────────────────────────────
  // Snackbar segura (sin usar context después de await)
  // ─────────────────────────────────────────────
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────
  // UI PRINCIPAL
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vendedores')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendedores'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Agregar', onPressed: _addSeller),
        ],
      ),
      body: _sellerIds.isEmpty
          ? const Center(child: Text('No hay vendedores aún'))
          : ListView.builder(
        itemCount: _sellerIds.length,
        itemBuilder: (context, i) {
          final id = _sellerIds[i];
          return FutureBuilder<Map<String, String>>(
            future: _getSellerData(id),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const ListTile(title: Text('Cargando...'));
              }
              final d = snap.data!;
              final name = d['name'] ?? '';
              final phone = d['phone'] ?? '';
              final msg = d['message'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Radio<int>(
                    value: id,
                    groupValue: _activeSellerId,
                    onChanged: (v) {
                      if (v != null) _setActiveSeller(v);
                    },
                  ),
                  title: Text(name.isEmpty ? 'Vendedor $id' : name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (phone.isNotEmpty) Text('Tel: $phone'),
                      if (msg.isNotEmpty) Text('Msg: $msg'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editSeller(id)),
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteSeller(id)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
