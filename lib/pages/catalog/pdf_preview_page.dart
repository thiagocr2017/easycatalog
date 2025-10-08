import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/pdf_service.dart';

class PdfPreviewPage extends StatefulWidget {
  const PdfPreviewPage({super.key});

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  final pdfService = PdfService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa del Catálogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            tooltip: 'Guardar PDF en Mac',
            onPressed: _savePdfLocally,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir catálogo',
            onPressed: _sharePdfFile,
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfService.buildFullCatalog(),
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: false,
        allowSharing: false,
        canDebug: false,
      ),
    );
  }

  Future<void> _savePdfLocally() async {
    try {
      final pdfBytes = await pdfService.buildFullCatalog();
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar catálogo',
        fileName: 'catalogo_hyj.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (output == null) return;
      final file = File(output);
      await file.writeAsBytes(pdfBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Guardado en: $output')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  Future<void> _sharePdfFile() async {
    try {
      final pdfBytes = await pdfService.buildFullCatalog();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/catalogo_hyj.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
        'Te comparto el catálogo de HyJ Souvenir Bisutería 📿✨\n¡Haz tu pedido por WhatsApp!',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
    }
  }
}
