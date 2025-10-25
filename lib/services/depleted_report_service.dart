import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/database_helper.dart';
import '../models/product.dart';

class DepletedReportService {
  final _db = DatabaseHelper.instance;

  // ─────────────────────────────────────────────
  // Reporte de productos agotados (paginado)
  // ─────────────────────────────────────────────
  Future<Uint8List> buildDepletedProductsReport(List<Product> products) async {
    final doc = pw.Document();


    // 🔹 Cargar fuentes
    final montserrat =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
    final openSans =
    pw.Font.ttf(await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'));

    // 🔹 Filtrar productos activos y agotados
    final depleted = products.where((p) => p.isActive && p.isDepleted).toList();

    // 🔹 Cargar logs y fechas para cada producto
    final productData = <Map<String, dynamic>>[];
    for (final p in depleted) {
      final createdAt = DateTime.tryParse(p.createdAt);
      final depletedAt = DateTime.tryParse(p.depletedAt ?? '');
      final logs = await _db.getProductLogs(p.id!);

      DateTime? lastReactivation;
      for (final log in logs) {
        if (log['action'] == 'reactivado') {
          final d = DateTime.tryParse(log['timestamp']);
          if (d != null) {
            if (lastReactivation == null || d.isAfter(lastReactivation)) {
              lastReactivation = d;
            }
          }
        }
      }

      productData.add({
        'product': p,
        'createdAt': createdAt,
        'depletedAt': depletedAt,
        'lastReactivation': lastReactivation,
      });
    }

    // 🔹 Paginación: 6 productos por hoja
    const itemsPerPage = 6;
    final totalPages = (productData.length / itemsPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final start = pageIndex * itemsPerPage;
      final end = (start + itemsPerPage).clamp(0, productData.length);
      final pageItems = productData.sublist(start, end);

      // 🔹 Resolver rutas relativas antes de construir cada página
      final resolvedImages = <int, File?>{};
      for (final entry in pageItems) {
        final Product p = entry['product'];
        resolvedImages[p.id ?? -1] = await _db.resolveImageFile(p.imagePath);
      }

      // 🔹 Agregar página al PDF
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado de la página
              pw.Text(
                'Reporte de Productos Agotados',
                style: pw.TextStyle(
                  font: montserrat,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Página ${pageIndex + 1} de $totalPages',
                style: pw.TextStyle(
                  font: openSans,
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 20),

              // Contenido de productos (máx 6 por hoja)
              for (final entry in pageItems)
                _buildDepletedCard(
                  entry,
                  montserrat,
                  openSans,
                  resolvedImages[(entry['product'] as Product).id ?? -1],
                ),
            ],
          ),
        ),
      );
    }

    if (depleted.isEmpty) {
      throw Exception('No hay productos activos agotados para generar el reporte.');
    }

    return doc.save();
  }

  // ─────────────────────────────────────────────
  // Tarjeta individual de producto agotado
  // ─────────────────────────────────────────────
  pw.Widget _buildDepletedCard(
      Map<String, dynamic> entry,
      pw.Font montserrat,
      pw.Font openSans,
      File? imageFile,
      ) {
    final Product p = entry['product'];
    final createdAt = entry['createdAt'] as DateTime?;
    final depletedAt = entry['depletedAt'] as DateTime?;
    final lastReactivation = entry['lastReactivation'] as DateTime?;

    // 🔹 Preparar imagen relativa o absoluta
    final exists = imageFile != null && imageFile.existsSync();
    pw.ImageProvider? img;
    if (exists) {
      img = pw.MemoryImage(imageFile.readAsBytesSync());
    }

    // 🔹 Formato de fechas
    final logText = StringBuffer();
    if (createdAt != null) {
      logText.writeln('Creado: ${createdAt.day}/${createdAt.month}/${createdAt.year}');
    }
    if (lastReactivation != null) {
      logText.writeln(
          'Reactivado: ${lastReactivation.day}/${lastReactivation.month}/${lastReactivation.year}');
    }
    if (depletedAt != null) {
      logText.writeln(
          'Agotado: ${depletedAt.day}/${depletedAt.month}/${depletedAt.year}');
    }

    // 🔹 Tarjeta del producto
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 🖼️ Imagen del producto (rutas relativas compatibles)
          pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: exists
                ? pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(img!, fit: pw.BoxFit.cover),
            )
                : pw.Center(
              child: pw.Text(
                'Sin imagen',
                style: pw.TextStyle(
                  font: openSans,
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 12),

          // 🧾 Información textual
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  p.name,
                  style: pw.TextStyle(
                    font: montserrat,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  p.description,
                  style: pw.TextStyle(
                    font: openSans,
                    fontSize: 12,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.Text(
                  'Precio: \$${p.price.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    font: openSans,
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  logText.toString(),
                  style: pw.TextStyle(
                    font: openSans,
                    fontSize: 11,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}