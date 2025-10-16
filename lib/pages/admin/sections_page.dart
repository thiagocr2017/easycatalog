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
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  // ─────────────────────────────────────────────
  // CARGAR SECCIONES
  // ─────────────────────────────────────────────
  Future<void> _loadSections() async {
    final data = await _db.getSections();
    if (!mounted) return;
    setState(() {
      _sections = data.map((e) => Section.fromMap(e)).toList()
        ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
      _hasUnsavedChanges = false;
    });
  }

  // ─────────────────────────────────────────────
  // GUARDAR ORDEN Y MOSTRAR FEEDBACK
  // ─────────────────────────────────────────────
  Future<void> _saveNewOrder() async {
    for (int i = 0; i < _sections.length; i++) {
      final s = _sections[i];
      await _db.updateSection({'id': s.id, 'name': s.name, 'sortOrder': i});
    }
    if (!mounted) return;
    setState(() => _hasUnsavedChanges = false);
    _safeSnack('Orden guardada correctamente');
  }

  // ─────────────────────────────────────────────
  // AGREGAR SECCIÓN
  // ─────────────────────────────────────────────
  Future<void> _addSection() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    await _db.insertSection({'name': name, 'sortOrder': _sections.length});
    _controller.clear();

    if (!mounted) return;
    _safeSnack('Sección "$name" agregada');
    _loadSections();
  }

  // ─────────────────────────────────────────────
  // EDITAR SECCIÓN
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
      _safeSnack('Sección actualizada a "$newName"');
      _loadSections();
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

    if (confirm == true) {
      await _db.deleteSection(section.id!);
      if (!mounted) return;
      _safeSnack('Sección "${section.name}" eliminada');
      _loadSections();
    }
  }

  // ─────────────────────────────────────────────
  // CONFIRMAR SALIDA SIN GUARDAR
  // ─────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text(
            'Has cambiado el orden de las secciones.\n¿Deseas salir sin guardar los cambios?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
          ],
        ),
      );
      return confirm ?? false;
    }
    return true;
  }

  // ─────────────────────────────────────────────
  // SNACKBAR SEGURO
  // ─────────────────────────────────────────────
  void _safeSnack(String message) {
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ─────────────────────────────────────────────
  // UI PRINCIPAL
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await _onWillPop();
        if (confirm && context.mounted) {
          Navigator.pop(context);
        }

      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secciones'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_outlined),
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
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _sections.removeAt(oldIndex);
                      _sections.insert(newIndex, item);
                      _hasUnsavedChanges = true;
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
      ),
    );
  }
}
