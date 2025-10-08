import 'dart:io';
import 'dart:typed_data'; // ✅ necesario
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_service.dart';

class PdfPreviewPage extends StatefulWidget {
  final Future<List<int>> Function(PdfPageFormat)? customBuilder;
  final String title;
  final String fileName;

  const PdfPreviewPage({
    super.key,
    this.customBuilder,
    this.title = 'Vista previa del Catálogo',
    this.fileName = 'catalogo_hyj.pdf',
  });

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  final pdfService = PdfService();

  Future<void> _savePdfLocally(Uint8List pdfBytes) async {
    try {
      final output = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar PDF',
        fileName: widget.fileName,
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

  Future<void> _sharePdfFile(Uint8List pdfBytes) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/${widget.fileName}');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Te comparto el ${widget.title.toLowerCase()} 📦',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: const []),
      body: PdfPreview(
        build: (format) async {
          final pdf = widget.customBuilder != null
              ? Uint8List.fromList(await widget.customBuilder!(format))
              : await pdfService.buildFullCatalog();
          return pdf;
        },
        initialPageFormat: PdfPageFormat.a4,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: false,
        allowSharing: false,
        canDebug: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            tooltip: 'Guardar PDF',
            onPressed: () async {
              final pdfBytes = widget.customBuilder != null
                  ? Uint8List.fromList(await widget.customBuilder!(PdfPageFormat.a4))
                  : await pdfService.buildFullCatalog();
              await _savePdfLocally(pdfBytes);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir PDF',
            onPressed: () async {
              final pdfBytes = widget.customBuilder != null
                  ? Uint8List.fromList(await widget.customBuilder!(PdfPageFormat.a4))
                  : await pdfService.buildFullCatalog();
              await _sharePdfFile(pdfBytes);
            },
          ),
        ],
      ),
    );
  }
}
