import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';
import '../data/database_helper.dart';
import '../models/product.dart';
import '../models/section.dart';
import '../models/style_settings.dart';
import '../models/seller_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfService {
  final _db = DatabaseHelper.instance;

  // ─────────────────────────────────────────────
  // Cargar configuración visual
  // ─────────────────────────────────────────────
  Future<StyleSettings> _loadStyle() async {
    final bg = await _db.getSetting('style.backgroundColor');
    final hl = await _db.getSetting('style.highlightColor');
    final ib = await _db.getSetting('style.infoBoxColor');
    final tx = await _db.getSetting('style.textColor');
    final lg = await _db.getSetting('style.logoPath');
    return StyleSettings(
      backgroundColor: int.tryParse(bg ?? '') ?? 0xFFE1F6B4,
      highlightColor: int.tryParse(hl ?? '') ?? 0xFF50B203,
      infoBoxColor: int.tryParse(ib ?? '') ?? 0xFFEEE9CC,
      textColor: int.tryParse(tx ?? '') ?? 0xFF222222,
      logoPath: lg,
    );
  }

  // ─────────────────────────────────────────────
  // Cargar vendedor activo
  // ─────────────────────────────────────────────
  Future<SellerSettings> _loadSellerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('activeSellerId') ?? 1;
    final data = await _db.getSellerSettings(activeId);
    return SellerSettings(
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      message: data['message'] ?? '',
    );
  }

  // ─────────────────────────────────────────────
  // Cargar métodos de pago
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _loadPaymentMethods() async {
    return await _db.getPaymentMethods();
  }

  // ─────────────────────────────────────────────
  // Conversión de color ARGB → PdfColor
  // ─────────────────────────────────────────────
  PdfColor _colorFromInt(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    return PdfColor(r, g, b);
  }

  // ─────────────────────────────────────────────
  // Construir catálogo completo
  // ─────────────────────────────────────────────
  Future<Uint8List> buildFullCatalog() async {
    final doc = pw.Document();
    final style = await _loadStyle();
    final seller = await _loadSellerSettings();
    final payments = await _loadPaymentMethods();

    final montserrat =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
    final openSans =
    pw.Font.ttf(await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'));
    final playlist =
    pw.Font.ttf(await rootBundle.load('assets/fonts/PlaylistScript.otf'));
    final bukhari =
    pw.Font.ttf(await rootBundle.load('assets/fonts/BukhariScript.ttf'));

    final sections =
    (await _db.getSections()).map((m) => Section.fromMap(m)).toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

    // Portada
    doc.addPage(_buildCoverPage(style, seller, payments, montserrat, playlist, bukhari));

    // Secciones + productos
    final allProducts =
    (await _db.getProducts()).map((m) => Product.fromMap(m)).toList();

    for (final section in sections) {
      final products = allProducts
          .where((p) => p.sectionId == section.id && !p.isDepleted)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (products.isEmpty) continue;

      doc.addPage(_buildSectionPage(section, style, montserrat));
      for (var i = 0; i < products.length; i += 2) {
        final slice = products.sublist(i, (i + 2).clamp(0, products.length));
        doc.addPage(_buildProductsPage(slice, style, montserrat, openSans));
      }
    }

    return doc.save();
  }

  // ─────────────────────────────────────────────
  // Portada del catálogo
  // ─────────────────────────────────────────────
  // ─────────────────────────────────────────────
// Portada del catálogo (versión corregida sin bordes blancos)
// ─────────────────────────────────────────────
  pw.Page _buildCoverPage(
      StyleSettings s,
      SellerSettings seller,
      List<Map<String, dynamic>> payments,
      pw.Font montserrat,
      pw.Font playlist,
      pw.Font bukhari,
      ) {
    final qr = Barcode.qrCode();
    final cleanedPhone = seller.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedMsg = Uri.encodeComponent(seller.message);
    final waLink = 'https://wa.me/$cleanedPhone?text=$encodedMsg';
    final svgData = qr.toSvg(waLink, width: 80, height: 80);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Container(
        width: double.infinity,
        height: double.infinity,
        color: _colorFromInt(s.backgroundColor), // ✅ Fondo completo
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(32), // ✅ Solo afecta al contenido
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // 🔹 Logo o título
              if (s.logoPath != null && File(s.logoPath!).existsSync())
                pw.Image(
                  pw.MemoryImage(File(s.logoPath!).readAsBytesSync()),
                  height: 160,
                )
              else
                pw.Text(
                  'HyJ Souvenir Bisutería',
                  style: pw.TextStyle(
                    font: bukhari,
                    fontSize: 36,
                    color: _colorFromInt(s.textColor),
                  ),
                ),

              pw.SizedBox(height: 24),

              // 🔹 Datos del vendedor
              pw.Text(
                seller.name,
                style: pw.TextStyle(
                  font: montserrat,
                  fontSize: 18,
                  color: _colorFromInt(s.textColor),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                seller.phone,
                style: pw.TextStyle(
                  font: montserrat,
                  fontSize: 14,
                  color: _colorFromInt(s.textColor),
                ),
              ),

              pw.SizedBox(height: 24),

              // 🔹 Código QR de contacto
              pw.SvgImage(svg: svgData),

              pw.SizedBox(height: 40),

              // 🔹 Métodos de pago
              if (payments.isNotEmpty)
                pw.Column(
                  children: [
                    pw.Text(
                      'Métodos de Pago',
                      style: pw.TextStyle(
                        font: montserrat,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                        color: _colorFromInt(s.highlightColor),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    ...payments.map((pm) {
                      final logo = pm['logoPath'] as String?;
                      final name = (pm['name'] ?? '').toString();
                      final info = (pm['info'] ?? '').toString();
                      final beneficiary =
                      (pm['beneficiary'] ?? '').toString();

                      return pw.Padding(
                        padding:
                        const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          mainAxisAlignment:
                          pw.MainAxisAlignment.center,
                          children: [
                            if (logo != null && File(logo).existsSync())
                              pw.Image(
                                pw.MemoryImage(
                                    File(logo).readAsBytesSync()),
                                height: 40,
                              ),
                            pw.SizedBox(width: 8),
                            pw.Column(
                              crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  name,
                                  style: pw.TextStyle(
                                    font: montserrat,
                                    fontSize: 12,
                                  ),
                                ),
                                pw.Text(
                                  info,
                                  style: pw.TextStyle(
                                    font: montserrat,
                                    fontSize: 10,
                                  ),
                                ),
                                pw.Text(
                                  beneficiary,
                                  style: pw.TextStyle(
                                    font: montserrat,
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _colorFromInt(
                                        s.highlightColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

/*  pw.Page _buildCoverPage(
      StyleSettings s,
      SellerSettings seller,
      List<Map<String, dynamic>> payments,
      pw.Font montserrat,
      pw.Font playlist,
      pw.Font bukhari,
      ) {
    final qr = Barcode.qrCode();
    final cleanedPhone = seller.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedMsg = Uri.encodeComponent(seller.message);
    final waLink = 'https://wa.me/$cleanedPhone?text=$encodedMsg';
    final svgData = qr.toSvg(waLink, width: 80, height: 80);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Container(
        color: _colorFromInt(s.backgroundColor),
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (s.logoPath != null && File(s.logoPath!).existsSync())
              pw.Image(pw.MemoryImage(File(s.logoPath!).readAsBytesSync()), height: 160)
            else
              pw.Text(
                'HyJ Souvenir Bisutería',
                style: pw.TextStyle(font: bukhari, fontSize: 36, color: _colorFromInt(s.textColor)),
              ),
            pw.SizedBox(height: 24),
            pw.Text(seller.name, style: pw.TextStyle(font: montserrat, fontSize: 18, color: _colorFromInt(s.textColor))),
            pw.SizedBox(height: 4),
            pw.Text(seller.phone, style: pw.TextStyle(font: montserrat, fontSize: 14, color: _colorFromInt(s.textColor))),
            pw.SizedBox(height: 24),
            pw.SvgImage(svg: svgData),
            pw.SizedBox(height: 40),
            if (payments.isNotEmpty)
              pw.Column(
                children: [
                  pw.Text('Métodos de Pago',
                      style: pw.TextStyle(
                          font: montserrat,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                          color: _colorFromInt(s.highlightColor))),
                  pw.SizedBox(height: 12),
                  ...payments.map((pm) {
                    final logo = pm['logoPath'] as String?;
                    final name = (pm['name'] ?? '').toString();
                    final info = (pm['info'] ?? '').toString();
                    final beneficiary = (pm['beneficiary'] ?? '').toString();

                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          if (logo != null && File(logo).existsSync())
                            pw.Image(pw.MemoryImage(File(logo).readAsBytesSync()), height: 40),
                          pw.SizedBox(width: 8),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(name, style: pw.TextStyle(font: montserrat, fontSize: 12)),
                              pw.Text(info, style: pw.TextStyle(font: montserrat, fontSize: 10)),
                              pw.Text(beneficiary,
                                  style: pw.TextStyle(
                                      font: montserrat,
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: _colorFromInt(s.highlightColor))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }*/

  // ─────────────────────────────────────────────
  // Página de sección
  // ─────────────────────────────────────────────
  pw.Page _buildSectionPage(Section section, StyleSettings s, pw.Font font) => pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Container(
      color: _colorFromInt(s.backgroundColor),
      child: pw.Center(
        child: pw.Text(section.name.toUpperCase(),
            style: pw.TextStyle(
                font: font,
                fontWeight: pw.FontWeight.bold,
                fontSize: 36,
                color: _colorFromInt(s.highlightColor))),
      ),
    ),
  );

  // ─────────────────────────────────────────────
  // Página de productos
  // ─────────────────────────────────────────────
  pw.Page _buildProductsPage(List<Product> products, StyleSettings s, pw.Font titleFont, pw.Font textFont) => pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Container(
      color: _colorFromInt(s.backgroundColor),
      padding: const pw.EdgeInsets.all(24),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: products.map((p) => _productCard(p, s, titleFont, textFont)).toList(),
      ),
    ),
  );

  // ─────────────────────────────────────────────
  // Tarjeta de producto
  // ─────────────────────────────────────────────
  pw.Widget _productCard(Product p, StyleSettings s, pw.Font titleFont, pw.Font textFont) {
    final hasImage = p.imagePath != null && File(p.imagePath!).existsSync();
    pw.ImageProvider? img;
    if (hasImage) img = pw.MemoryImage(File(p.imagePath!).readAsBytesSync());

    return pw.Container(
      height: 320,
      margin: const pw.EdgeInsets.symmetric(vertical: 12),
      decoration: pw.BoxDecoration(color: _colorFromInt(s.infoBoxColor), borderRadius: pw.BorderRadius.circular(12)),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 180,
            height: 260,
            decoration:
            pw.BoxDecoration(color: _colorFromInt(s.highlightColor), borderRadius: pw.BorderRadius.circular(16)),
            child: hasImage
                ? pw.ClipRRect(
              horizontalRadius: 16,
              verticalRadius: 16,
              child: pw.Image(img!, fit: pw.BoxFit.cover),
            )
                : pw.Center(
              child: pw.Text('Sin imagen',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: textFont, fontSize: 12, color: _colorFromInt(s.textColor))),
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 14),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14), // más alto y más ancho
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    color: _colorFromInt(s.highlightColor),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Align(
                    child: pw.Text(
                      p.name,
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(
                        font: titleFont,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 22, // un poco más grande
                        color: _colorFromInt(s.backgroundColor),
                      ),
                    ),
                  ),
                ),
                pw.Text(p.description,
                    style: pw.TextStyle(font: textFont, fontSize: 14, color: _colorFromInt(s.textColor))),
                pw.SizedBox(height: 12),
                pw.Text('\$${p.price.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        font: titleFont,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 20,
                        color: _colorFromInt(s.highlightColor))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Reporte de productos agotados con fecha de reactivación
  // ─────────────────────────────────────────────
  Future<Uint8List> buildDepletedProductsReport(List<Product> products) async {
    final doc = pw.Document();
    final montserrat = pw.Font.ttf(await rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
    final openSans = pw.Font.ttf(await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'));

    // 🔹 Preparamos los datos primero (antes del map)
    final productData = <Map<String, dynamic>>[];

    for (final p in products) {
      final createdAt = DateTime.tryParse(p.createdAt);
      final depletedAt = DateTime.tryParse(p.depletedAt ?? '');
      final logs = await _db.getProductLogs(p.id!);

      // Encontrar última reactivación
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

    // 🔹 Construcción del PDF
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Reporte de Productos Agotados',
              style: pw.TextStyle(
                font: montserrat,
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            ...productData.map((entry) {
              final Product p = entry['product'];
              final createdAt = entry['createdAt'] as DateTime?;
              final depletedAt = entry['depletedAt'] as DateTime?;
              final lastReactivation = entry['lastReactivation'] as DateTime?;
              final img = (p.imagePath != null && File(p.imagePath!).existsSync())
                  ? pw.MemoryImage(File(p.imagePath!).readAsBytesSync())
                  : null;

              final logText = StringBuffer();
              if (createdAt != null) {
                logText.writeln('Creado: ${createdAt.day}/${createdAt.month}/${createdAt.year}');
              }
              if (lastReactivation != null) {
                logText.writeln('Reactivado: ${lastReactivation.day}/${lastReactivation.month}/${lastReactivation.year}');
              }
              if (depletedAt != null) {
                logText.writeln('Agotado: ${depletedAt.day}/${depletedAt.month}/${depletedAt.year}');
              }

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
                    pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: img != null
                          ? pw.ClipRRect(
                        horizontalRadius: 6,
                        verticalRadius: 6,
                        child: pw.Image(img, fit: pw.BoxFit.cover),
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
                            style: pw.TextStyle(font: openSans, fontSize: 12),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            logText.toString(),
                            style: pw.TextStyle(font: openSans, fontSize: 11, color: PdfColors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );

    return doc.save();
  }
}
