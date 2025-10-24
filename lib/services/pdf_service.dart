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
import '../../widgets/product_image_preview.dart' show ProductImagePreview;

class PdfService {
  final _db = DatabaseHelper.instance;

  static const double imgWidth = ProductImagePreview.baseWidth;
  static const double imgHeight = ProductImagePreview.baseHeight;

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
    doc.addPage(
        _buildCoverPage(style, seller, payments, montserrat, playlist, bukhari));

    // Secciones + productos
    final allProducts =
    (await _db.getProducts()).map((m) => Product.fromMap(m)).toList();

    // 🔹 Filtra productos activos y no agotados
    final activeProducts =
    allProducts.where((p) => p.isActive && !p.isDepleted).toList();

    for (final section in sections) {
      final products = activeProducts
          .where((p) => p.sectionId == section.id)
          .toList()
        ..sort((a, b) {
          final sa = a.sortOrder;
          final sb = b.sortOrder;
          if (sa != sb) return sa.compareTo(sb);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

      if (products.isEmpty) continue;
      doc.addPage(_buildSectionPage(section, style, montserrat));

      for (var i = 0; i < products.length; i += 2) {
        final slice = products.sublist(i, (i + 2).clamp(0, products.length));

        final imageSettings = <int, Map<String, double>>{};
        for (final prod in slice) {
          final conf = await _db.getImageSetting(prod.id ?? -1);
          imageSettings[prod.id ?? -1] = {
            'zoom': conf?.zoom ?? 1.0,
            'offsetX': conf?.offsetX ?? 0.0,
            'offsetY': conf?.offsetY ?? 0.0,
          };
        }

        doc.addPage(await _buildProductsPage(slice, style, montserrat, openSans, imageSettings));
      }
    }

    return doc.save();
  }

  // ─────────────────────────────────────────────
  // Portada del catálogo
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
        color: _colorFromInt(s.backgroundColor),
        child: pw.Padding(
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
                  style: pw.TextStyle(
                    font: bukhari,
                    fontSize: 36,
                    color: _colorFromInt(s.textColor),
                  ),
                ),
              pw.SizedBox(height: 24),
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
              pw.SvgImage(svg: svgData),
              pw.SizedBox(height: 40),
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
                                pw.Text(
                                  beneficiary,
                                  style: pw.TextStyle(
                                    font: montserrat,
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: _colorFromInt(s.highlightColor),
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

  // ─────────────────────────────────────────────
  // Página de sección
  // ─────────────────────────────────────────────
  pw.Page _buildSectionPage(Section section, StyleSettings s, pw.Font font) =>
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Container(
          color: _colorFromInt(s.backgroundColor),
          child: pw.Center(
            child: pw.Text(
              section.name.toUpperCase(),
              style: pw.TextStyle(
                font: font,
                fontWeight: pw.FontWeight.bold,
                fontSize: 36,
                color: _colorFromInt(s.highlightColor),
              ),
            ),
          ),
        ),
      );

  // ─────────────────────────────────────────────
  // Página de productos (resuelve imágenes antes)
  // ─────────────────────────────────────────────
  Future<pw.Page> _buildProductsPage(
      List<Product> products,
      StyleSettings s,
      pw.Font titleFont,
      pw.Font textFont,
      Map<int, Map<String, double>> imageSettings,
      ) async {
    final resolvedImages = <int, File?>{};
    for (final p in products) {
      resolvedImages[p.id ?? -1] = await _db.resolveImageFile(p.imagePath);
    }

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Container(
        color: _colorFromInt(s.backgroundColor),
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            for (final p in products)
              _productCard(
                p,
                s,
                titleFont,
                textFont,
                imageSettings[p.id ?? -1],
                resolvedImages[p.id ?? -1],
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Tarjeta de producto (usa resolveImageFile)
  // ─────────────────────────────────────────────
  pw.Widget _productCard(
      Product p,
      StyleSettings s,
      pw.Font titleFont,
      pw.Font textFont,
      Map<String, double>? imageSetting,
      File? imageFile,
      ) {
    final zoom = imageSetting?['zoom'] ?? 1.0;
    final offsetX = imageSetting?['offsetX'] ?? 0.0;
    final offsetY = imageSetting?['offsetY'] ?? 0.0;

    final exists = imageFile != null && imageFile.existsSync();
    pw.ImageProvider? img;
    if (exists) {
      img = pw.MemoryImage(imageFile.readAsBytesSync());
    }

    return pw.Container(
      height: imgHeight + 60,
      margin: const pw.EdgeInsets.symmetric(vertical: 12),
      decoration: pw.BoxDecoration(
        color: _colorFromInt(s.infoBoxColor),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: imgWidth,
            height: imgHeight,
            decoration: pw.BoxDecoration(
              color: _colorFromInt(s.highlightColor),
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(
                color: _colorFromInt(s.highlightColor),
                width: 5.0,
              ),
            ),
            child: exists
                ? pw.ClipRRect(
              horizontalRadius: 16,
              verticalRadius: 16,
              child: pw.Transform.translate(
                offset: PdfPoint(offsetX * 35, -offsetY * 35),
                child: pw.Transform.scale(
                  scale: zoom,
                  child: pw.Image(img!, fit: pw.BoxFit.cover),
                ),
              ),
            )
                : pw.Center(
              child: pw.Text(
                'Sin imagen',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: textFont,
                  fontSize: 12,
                  color: _colorFromInt(s.textColor),
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 14),
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: pw.BoxDecoration(
                        color: _colorFromInt(s.highlightColor),
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.Text(
                        p.name,
                        textAlign: pw.TextAlign.left,
                        style: pw.TextStyle(
                          font: titleFont,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 22,
                          color: _colorFromInt(s.backgroundColor),
                        ),
                      ),
                    ),
                  ),
                ),
                pw.Text(
                  p.description,
                  style: pw.TextStyle(
                    font: textFont,
                    fontSize: 14,
                    color: _colorFromInt(s.textColor),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  '\$${p.price.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    font: titleFont,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 20,
                    color: _colorFromInt(s.highlightColor),
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
