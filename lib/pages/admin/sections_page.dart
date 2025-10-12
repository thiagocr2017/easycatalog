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

  Future<void> _loadSections() async {
    final data = await _db.getSections();
    if (!mounted) return;
    setState(() {
      _sections = data.map((e) => Section.fromMap(e)).toList()
        ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    });
  }

  Future<void> _saveNewOrder() async {
    for (int i = 0; i < _sections.length; i++) {
      final s = _sections[i];
      await _db.updateSection({'id': s.id, 'name': s.name, 'sortOrder': i});
    }
  }

  Future<void> _addSection() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    await _db.insertSection({'name': name, 'sortOrder': _sections.length});
    _controller.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Sección "$name" agregada')));
    _loadSections();
  }

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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName != null &&
        newName.isNotEmpty &&
        newName != section.name) {
      await _db.updateSection({
        'id': section.id,
        'name': newName,
        'sortOrder': section.sortOrder ?? 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sección actualizada a "$newName"')),
      );
      _loadSections();
    }
  }

  Future<void> _confirmDeleteSection(Section section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar sección'),
        content: Text(
            '¿Deseas eliminar la sección "${section.name}"?\n\nEsto no eliminará los productos, pero los dejará sin categoría.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteSection(section.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sección "${section.name}" eliminada')),
      );
      _loadSections();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Guardar orden',
            onPressed: _saveNewOrder,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Nueva sección',
                    ),
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
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _sections.removeAt(oldIndex);
                    _sections.insert(newIndex, item);
                  });
                },
                children: [
                  for (final section in _sections)
                    Card(
                      key: ValueKey(section.id),
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
                              onPressed: () =>
                                  _confirmDeleteSection(section),
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
