import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/product.dart';
import '../../services/pdf_service.dart';

class DepletedProductsPage extends StatefulWidget {
  const DepletedProductsPage({super.key});

  @override
  State<DepletedProductsPage> createState() => _DepletedProductsPageState();
}

class _DepletedProductsPageState extends State<DepletedProductsPage> {
  final _db = DatabaseHelper.instance;
  final _pdf = PdfService();
  List<Product> _depleted = [];

  @override
  void initState() {
    super.initState();
    _loadDepleted();
  }

  Future<void> _loadDepleted() async {
    final data = await _db.getProducts();
    setState(() {
      _depleted = data
          .map((e) => Product.fromMap(e))
          .where((p) => p.isDepleted)
          .toList()
        ..sort((a, b) {
          final da = DateTime.tryParse(a.depletedAt ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(b.depletedAt ?? '') ?? DateTime(2000);
          return db.compareTo(da); // más recientes primero
        });
    });
  }

  Future<void> _exportPdf() async {
    final pdfBytes = await _pdf.buildDepletedProductsReport(_depleted);
    final file = File('${Directory.systemTemp.path}/productos_agotados.pdf');
    await file.writeAsBytes(pdfBytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('PDF generado en ${file.path}')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos Agotados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportPdf,
          )
        ],
      ),
      body: _depleted.isEmpty
          ? const Center(child: Text('No hay productos agotados'))
          : ListView.builder(
        itemCount: _depleted.length,
        itemBuilder: (context, i) {
          final p = _depleted[i];
          final date = DateTime.tryParse(p.depletedAt ?? '');
          final formatted = date != null
              ? '${date.day}/${date.month}/${date.year}'
              : '';
          return ListTile(
            leading: p.imagePath != null && File(p.imagePath!).existsSync()
                ? Image.file(File(p.imagePath!), width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported),
            title: Text(p.name),
            subtitle: Text(
                '${p.description}\nPrecio: \$${p.price.toStringAsFixed(2)}\nAgotado: $formatted'),
          );
        },
      ),
    );
  }
}
