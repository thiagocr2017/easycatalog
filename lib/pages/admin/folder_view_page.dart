import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/image_manager.dart';

class FolderViewPage extends StatefulWidget {
  const FolderViewPage({super.key});

  @override
  State<FolderViewPage> createState() => _FolderViewPageState();
}

class _FolderViewPageState extends State<FolderViewPage> {
  final List<String> _logs = [];
  bool _isOptimizing = false;

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _openFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final appDir = await getApplicationSupportDirectory();
      final imagesDir = Directory('${appDir.path}/images');

      if (!imagesDir.existsSync()) {
        await imagesDir.create(recursive: true);
        messenger.showSnackBar(
          SnackBar(content: Text('📂 Carpeta creada: ${imagesDir.path}')),
        );
      }

      await Process.run('open', [imagesDir.path]);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al abrir carpeta: $e')),
      );
    }
  }

  Future<void> _optimizeImages() async {
    setState(() {
      _isOptimizing = true;
      _logs.clear();
      _logs.add("🚀 Iniciando optimización de imágenes...");
    });

    final manager = ImageManager();

    // Escucha los logs del ImageManager mediante callback
    await manager.optimizeAllImagesWithCallback(
      quality: 70,
      maxSize: 1024,
      onLog: (msg) => _addLog(msg),
    );

    await manager.cleanOldImages();

    setState(() {
      _isOptimizing = false;
      _logs.add("🏁 Optimización finalizada.");
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Imágenes optimizadas y limpiadas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carpeta de Imágenes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Optimizar imágenes'),
              onPressed: _isOptimizing ? null : _optimizeImages,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openFolder,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Abrir carpeta en Finder'),
            ),
            const SizedBox(height: 24),
            if (_isOptimizing)
              const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: log.contains('✅')
                              ? Colors.greenAccent
                              : log.contains('⚠️')
                              ? Colors.orangeAccent
                              : log.contains('❌')
                              ? Colors.redAccent
                              : Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
