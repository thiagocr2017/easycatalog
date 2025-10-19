import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/section.dart';

class SectionsPage extends StatefulWidget {
  const SectionsPage({super.key});

  @override
  State<SectionsPage> createState() => _SectionsPageState();
}

class _SectionsPageState extends State<SectionsPage> {
  final _db = DatabaseHelper.instance;
  final _controller = TextEditingController();
  List<Section> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  // ─────────────────────────────────────────────
  // CARGAR SECCIONES DESDE DB
  // ─────────────────────────────────────────────
  Future<void> _loadSections() async {
    final data = await _db.getSections();
    if (!mounted) return;
    setState(() {
      _sections = data.map((e) => Section.fromMap(e)).toList()
        ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    });
  }

  // ─────────────────────────────────────────────
  // AGREGAR NUEVA SECCIÓN
  // ─────────────────────────────────────────────
  Future<void> _addSection() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    await _db.insertSection({'name': name, 'sortOrder': _sections.length});
    _controller.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sección "$name" agregada')),
    );

    await _loadSections();
  }

  // ─────────────────────────────────────────────
  // EDITAR NOMBRE DE SECCIÓN
  // ─────────────────────────────────────────────
  Future<void> _editSection(Section section) async {
    final controller = TextEditingController(text: section.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar sección'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != section.name) {
      await _db.updateSection({
        'id': section.id,
        'name': newName,
        'sortOrder': section.sortOrder ?? 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sección actualizada a "$newName"')),
      );
      await _loadSections();
    }
  }

  // ─────────────────────────────────────────────
  // ELIMINAR SECCIÓN
  // ─────────────────────────────────────────────
  Future<void> _confirmDeleteSection(Section section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar sección'),
        content: Text(
          '¿Deseas eliminar la sección "${section.name}"?\n\n'
              'Esto no eliminará los productos, pero los dejará sin categoría.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && section.id != null) {
      await _db.deleteSection(section.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sección "${section.name}" eliminada')),
      );
      await _loadSections();
    }
  }

  // ─────────────────────────────────────────────
  // REORDENAR Y GUARDAR AUTOMÁTICAMENTE
  // ─────────────────────────────────────────────
  Future<void> _reorderSections(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, item);
    });

    // ✅ Actualiza el orden en memoria y base de datos
    for (int i = 0; i < _sections.length; i++) {
      _sections[i].sortOrder = i;
      if (_sections[i].id != null) {
        await _db.updateSection({
          'id': _sections[i].id,
          'name': _sections[i].name,
          'sortOrder': i,
        });
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Orden actualizado automáticamente')),
    );
  }

  // ─────────────────────────────────────────────
  // UI PRINCIPAL
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secciones')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input para agregar sección
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: 'Nueva sección'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar sección',
                  onPressed: _addSection,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Lista con drag & drop
            Expanded(
              child: ReorderableListView(
                onReorder: _reorderSections,
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.green.shade50,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                ),
                children: [
                  for (final section in _sections)
                    Card(
                      key: ValueKey(section.id ?? section.name),
                      child: ListTile(
                        title: Text(section.name),
                        leading: const Icon(Icons.drag_handle),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Editar sección',
                              onPressed: () => _editSection(section),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar sección',
                              onPressed: () => _confirmDeleteSection(section),
                            ),
                          ],
                        ),
                      ),
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
