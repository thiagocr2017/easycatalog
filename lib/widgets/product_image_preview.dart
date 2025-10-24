// 📄 lib/widgets/product_image_preview.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../data/database_helper.dart';

/// Widget reutilizable para mostrar una imagen de producto
/// compatible con rutas relativas o absolutas.
/// - Aplica zoom y desplazamiento (offset)
/// - Mantiene proporción exacta del PDF (180×260)
class ProductImagePreview extends StatelessWidget {
  final String? imagePath;
  final double zoom;
  final double offsetX;
  final double offsetY;
  final double scaleFactor;

  static const double baseWidth = 180; // ancho base (PDF)
  static const double baseHeight = 260; // alto base (PDF)

  const ProductImagePreview({
    super.key,
    required this.imagePath,
    this.zoom = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.scaleFactor = 1.0,
  });

  /// 🔹 Resuelve automáticamente la ruta local (relativa o absoluta)
  Future<File?> _resolveFile() async {
    if (imagePath == null || imagePath!.isEmpty) return null;

    // Usa el método centralizado en DatabaseHelper (mejor para consistencia)
    final db = DatabaseHelper.instance;
    final file = await db.resolveImageFile(imagePath);

    // Compatibilidad extra: si no existe, intentar ruta local directa
    if (file != null && file.existsSync()) return file;

    // Último intento: ruta completa dentro de /images
    final appDir = await getApplicationSupportDirectory();
    final fallback = File('${appDir.path}/images/${imagePath!}');
    return fallback.existsSync() ? fallback : null;
  }

  @override
  Widget build(BuildContext context) {
    final width = baseWidth * scaleFactor;
    final height = baseHeight * scaleFactor;

    return FutureBuilder<File?>(
      future: _resolveFile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final file = snapshot.data;

        if (file == null || !file.existsSync()) {
          return Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: width,
            height: height,
            color: Colors.grey.shade100,
            child: Transform.translate(
              offset: Offset(offsetX * 35, offsetY * 35),
              child: Transform.scale(
                scale: zoom,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}