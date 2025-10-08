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
    setState(() {
      _sections = data.map((e) => Section.fromMap(e)).toList();
    });
  }

  Future<void> _addSection() async {
    if (_controller.text.trim().isEmpty) return;
    await _db.insertSection({'name': _controller.text.trim()});
    _controller.clear();
    _loadSections();
  }

  Future<void> _deleteSection(int id) async {
    await _db.deleteSection(id);
    _loadSections();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secciones')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Nueva sección',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addSection,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _sections.length,
                itemBuilder: (context, i) {
                  final section = _sections[i];
                  return ListTile(
                    title: Text(section.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteSection(section.id!),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
