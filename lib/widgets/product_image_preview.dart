import 'dart:io';
import 'package:flutter/material.dart';

class ProductImagePreview extends StatelessWidget {
  // 🔹 Ruta del archivo de imagen
  final String? imagePath;

  // 🔹 Transformaciones visuales
  final double zoom;
  final double offsetX;
  final double offsetY;

  // 🔹 Escala relativa al tamaño base (PDF)
  final double scaleFactor;

  // 🔹 Tamaño base tomado del PDF (constante global)
  static const double baseWidth = 180;
  static const double baseHeight = 260;

  const ProductImagePreview({
    super.key,
    this.imagePath,
    this.zoom = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.scaleFactor = 1.0, // 1.0 = igual al PDF
  });

  @override
  Widget build(BuildContext context) {
    // 🔹 Calculamos dimensiones escaladas
    final double width = baseWidth * scaleFactor;
    final double height = baseHeight * scaleFactor;

    if (imagePath == null || !File(imagePath!).existsSync()) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8 * scaleFactor),
      child: Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: Transform.translate(
          offset: Offset(offsetX * 20, offsetY * 20),
          child: Transform.scale(
            scale: zoom,
            child: Image.file(
              File(imagePath!),
              key: ValueKey(imagePath),
              fit: BoxFit.contain, // ✅ nunca recorta
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
    );
  }
}
