import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class FolderViewPage extends StatefulWidget {
  const FolderViewPage({super.key});

  @override
  State<FolderViewPage> createState() => _FolderViewPageState();
}

class _FolderViewPageState extends State<FolderViewPage> {
  Future<void> _openFolder() async {
    final messenger = ScaffoldMessenger.of(context); // ✅ capturado antes del await
    try {
      final appDir = await getApplicationSupportDirectory();
      final imagesDir = Directory('${appDir.path}/images');

      if (!imagesDir.existsSync()) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No hay carpeta de imágenes aún.')),
        );
        return;
      }
      await Process.run('open', [imagesDir.path]);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al abrir carpeta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carpeta de Imágenes')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _openFolder,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Abrir carpeta en Finder'),
        ),
      ),
    );
  }
}
