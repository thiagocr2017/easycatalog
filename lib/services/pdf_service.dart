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
      backgroundColor: int.tryParse(bg ?? '') ?? 0xFFF4F7F8,
      highlightColor: int.tryParse(hl ?? '') ?? 0xFF3A8FB7,
      infoBoxColor: int.tryParse(ib ?? '') ?? 0xFFE6E1C5,
      textColor: int.tryParse(tx ?? '') ?? 0xFF222222,
      logoPath: lg,
    );
  }

  // ─────────────────────────────────────────────
  // Cargar información del vendedor
  // ─────────────────────────────────────────────
 /* Future<SellerSettings> _loadSellerSettings() async {
    final name = await _db.getSetting('seller.name');
    final phone = await _db.getSetting('seller.phone');
    final msg = await _db.getSetting('seller.message');
    return SellerSettings(
      name: name ?? 'Thiago Hernández',
      phone: phone ?? '+52 55 1234 5678',
      message: msg ?? 'Hola Thiago, me gustaría hacer un pedido.',
    );
  }*/

  // ─────────────────────────────────────────────
  // Cargar información del vendedor activo
  // ─────────────────────────────────────────────
  Future<SellerSettings> _loadSellerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('activeSellerId') ?? 1;

    final data = await _db.getSellerSettings(activeId);

    return SellerSettings(
      name: data['name'] ?? 'Thiago Hernández',
      phone: data['phone'] ?? '+52 55 1234 5678',
      message: data['message'] ?? 'Hola Thiago, me gustaría hacer un pedido.',
    );
  }


  // ─────────────────────────────────────────────
  // Conversión de color
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

    final montserrat =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
    final openSans =
    pw.Font.ttf(await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'));
    final playlist =
    pw.Font.ttf(await rootBundle.load('assets/fonts/PlaylistScript.otf'));
    final bukhari =
    pw.Font.ttf(await rootBundle.load('assets/fonts/BukhariScript.ttf'));

    final sections =
    (await _db.getSections()).map((m) => Section.fromMap(m)).toList();

    // Portada
    doc.addPage(_buildCoverPage(style, seller, montserrat, playlist, bukhari));

    // Secciones + productos
    final allProducts =
    (await _db.getProducts()).map((m) => Product.fromMap(m)).toList();

    for (final section in sections) {
      final products = allProducts
          .where((p) => p.sectionId == section.id && !p.isDepleted)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (products.isEmpty) continue; // omitir secciones vacías

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
  pw.Page _buildCoverPage(
      StyleSettings s,
      SellerSettings seller,
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
      build: (context) {
        return pw.Container(
          width: double.infinity,
          height: double.infinity,
          color: _colorFromInt(s.backgroundColor),
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (s.logoPath != null && File(s.logoPath!).existsSync())
                  pw.Image(
                    pw.MemoryImage(File(s.logoPath!).readAsBytesSync()),
                    height: 180,
                  )
                else
                  pw.Column(
                    children: [
                      pw.Text(
                        'HyJ',
                        style: pw.TextStyle(
                          font: playlist,
                          fontSize: 60,
                          color: _colorFromInt(s.highlightColor),
                        ),
                      ),
                      pw.Text(
                        'Souvenir Bisutería',
                        style: pw.TextStyle(
                          font: bukhari,
                          fontSize: 28,
                          color: _colorFromInt(s.textColor),
                        ),
                      ),
                    ],
                  ),
                pw.SizedBox(height: 40),
                pw.Text(
                  seller.name,
                  style: pw.TextStyle(
                    font: montserrat,
                    fontSize: 20,
                    color: _colorFromInt(s.textColor),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  seller.phone,
                  style: pw.TextStyle(
                    font: montserrat,
                    fontSize: 16,
                    color: _colorFromInt(s.textColor),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.SvgImage(svg: svgData),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Página de sección
  // ─────────────────────────────────────────────
  pw.Page _buildSectionPage(Section sct, StyleSettings s, pw.Font font) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) {
        return pw.Container(
          width: double.infinity,
          height: double.infinity,
          color: _colorFromInt(s.backgroundColor),
          child: pw.Center(
            child: pw.Text(
              sct.name.toUpperCase(),
              style: pw.TextStyle(
                font: font,
                fontWeight: pw.FontWeight.bold,
                fontSize: 36,
                color: _colorFromInt(s.highlightColor),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Página de productos (2 por página)
  // ─────────────────────────────────────────────
  pw.Page _buildProductsPage(
      List<Product> products,
      StyleSettings s,
      pw.Font titleFont,
      pw.Font textFont,
      ) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        return pw.Container(
          color: _colorFromInt(s.backgroundColor),
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children:
            products.map((p) => _productCard(p, s, titleFont, textFont)).toList(),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Tarjeta de producto individual
  // ─────────────────────────────────────────────
  pw.Widget _productCard(
      Product p,
      StyleSettings s,
      pw.Font titleFont,
      pw.Font textFont,
      ) {
    final hasImage = p.imagePath != null && File(p.imagePath!).existsSync();
    pw.ImageProvider? img;
    if (hasImage) {
      final bytes = File(p.imagePath!).readAsBytesSync();
      img = pw.MemoryImage(bytes);
    }

    return pw.Container(
      height: 320,
      margin: const pw.EdgeInsets.symmetric(vertical: 12),
      decoration: pw.BoxDecoration(
        color: _colorFromInt(s.infoBoxColor),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Imagen del producto (vertical, bordes redondeados)
          pw.Container(
            width: 180,
            height: 260,
            decoration: pw.BoxDecoration(
              color: _colorFromInt(s.highlightColor),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: hasImage
                ? pw.ClipRRect(
              horizontalRadius: 16,
              verticalRadius: 16,
              child: pw.Image(
                img!,
                fit: pw.BoxFit.cover,
                alignment: pw.Alignment.center,
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
          // Información del producto
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: _colorFromInt(s.highlightColor),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  width: double.infinity,
                  child: pw.Text(
                    p.name,
                    textAlign: pw.TextAlign.left,
                    style: pw.TextStyle(
                      font: titleFont,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 20,
                      color: _colorFromInt(s.backgroundColor),
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
  // ─────────────────────────────────────────────
  // Generar el PDF de productos agotados
  // ─────────────────────────────────────────────
  Future<Uint8List> buildDepletedProductsReport(List<Product> products) async {
    final doc = pw.Document();
    final montserrat =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
    final openSans =
    pw.Font.ttf(await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'));

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reporte de Productos Agotados',
                  style: pw.TextStyle(
                      font: montserrat, fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              ...products.map((p) {
                final date = DateTime.tryParse(p.depletedAt ?? '');
                final formatted = date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : '';
                pw.ImageProvider? img;
                if (p.imagePath != null && File(p.imagePath!).existsSync()) {
                  img = pw.MemoryImage(File(p.imagePath!).readAsBytesSync());
                }
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 80,
                        height: 80,
                        color: PdfColors.grey300,
                        child: img != null
                            ? pw.Image(img, fit: pw.BoxFit.cover)
                            : pw.Center(child: pw.Text('Sin imagen')),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(p.name,
                                style: pw.TextStyle(
                                    font: montserrat,
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(p.description,
                                style: pw.TextStyle(
                                    font: openSans,
                                    fontSize: 12,
                                    color: PdfColors.grey800)),
                            pw.Text('Precio: \$${p.price.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                    font: openSans, fontSize: 12)),
                            pw.Text('Agotado: $formatted',
                                style: pw.TextStyle(
                                    font: openSans, fontSize: 11,
                                    color: PdfColors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
    return doc.save();
  }
}
