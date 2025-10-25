import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../data/database_helper.dart';
import '../models/product.dart';

class ImportExportService {
  final _db = DatabaseHelper.instance;

  // ─────────────────────────────────────────────
  // 📤 EXPORTAR PRODUCTOS A EXCEL
  // ─────────────────────────────────────────────
  Future<File?> exportToExcel(BuildContext context) async {
    try {
      final productsData = await _db.getProducts();
      final sectionsData = await _db.getSections();

      final products = productsData.map((e) => Product.fromMap(e)).toList();
      final sections = {for (var s in sectionsData) s['id']: s['name']};

      final excel = Excel.createExcel();
      final sheetName = excel.getDefaultSheet();
      final sheet = excel[sheetName ?? 'Sheet1']; // reutiliza la hoja por defecto

      // Cabeceras
      sheet.appendRow(const [
        'ID',
        'Nombre',
        'Descripción',
        'Precio',
        'Sección',
        'Imagen',
        'Activo',
        'Agotado',
        'Orden'
      ]);

      // Filas
      for (final p in products) {
        sheet.appendRow([
          p.id ?? '',
          p.name,
          p.description,
          p.price,
          sections[p.sectionId] ?? '',
          p.imagePath ?? '',
          p.isActive ? 'Sí' : 'No',
          p.isDepleted ? 'Sí' : 'No',
          p.sortOrder,
        ]);
      }

      final timestamp =
      DateTime.now().toIso8601String().replaceAll(':', '-');
      final suggestedName = 'catalogo_exportado_$timestamp.xlsx';

      // 📁 Diálogo “Guardar como...”
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar catálogo como...',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (savePath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exportación cancelada.')),
          );
        }
        return null;
      }

      final file = File(savePath);
      await file.writeAsBytes(excel.encode()!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Archivo exportado en:\n$savePath')),
        );
      }

      if (Platform.isMacOS) {
        Process.run('open', [savePath]);
      } else if (Platform.isWindows) {
        Process.run('explorer', [savePath]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [savePath]);
      }

      return file;
    } catch (e) {
      debugPrint('❌ Error exportando Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // 📥 IMPORTAR PRODUCTOS DESDE EXCEL (con estadísticas)
  // ─────────────────────────────────────────────
  Future<Map<String, int>> importFromExcel(BuildContext context) async {
    final results = {'inserted': 0, 'updated': 0};

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Seleccionar archivo Excel',
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importación cancelada.')),
          );
        }
        return results;
      }

      final filePath = result.files.single.path!;
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.sheets.values.first;

      if (sheet.rows.isEmpty) {
        throw Exception('El archivo Excel no contiene datos válidos.');
      }

      final db = await _db.database;

      // 🔁 Procesar filas (saltando encabezado)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final id = int.tryParse('${row[0]?.value ?? ''}');
        final name = '${row[1]?.value ?? ''}';
        if (name.isEmpty) continue;

        final desc = '${row[2]?.value ?? ''}';
        final price = double.tryParse('${row[3]?.value ?? '0'}') ?? 0.0;
        final sectionName = '${row[4]?.value ?? ''}';
        final imagePath = '${row[5]?.value ?? ''}';
        final isActive = '${row[6]?.value ?? 'Sí'}'.toLowerCase() == 'sí';
        final isDepleted = '${row[7]?.value ?? 'No'}'.toLowerCase() == 'sí';
        final sortOrder = int.tryParse('${row[8]?.value ?? '0'}') ?? 0;

        // 🔍 Buscar o crear sección
        int? sectionId;
        if (sectionName.isNotEmpty) {
          final section = await db.query(
            'sections',
            where: 'name = ?',
            whereArgs: [sectionName],
          );
          if (section.isEmpty) {
            sectionId =
            await _db.insertSection({'name': sectionName, 'sortOrder': 0});
          } else {
            sectionId = section.first['id'] as int?;
          }
        }

        final product = Product(
          id: id,
          name: name,
          description: desc,
          price: price,
          sectionId: sectionId,
          imagePath: imagePath,
          isActive: isActive,
          isDepleted: isDepleted,
          sortOrder: sortOrder,
        );

        if (id != null) {
          final count = await _db.updateProduct(product.toMap());
          if (count > 0) {
            results['updated'] = (results['updated'] ?? 0) + 1;
            continue;
          }
        }

        await _db.insertProduct(product.toMap());
        results['inserted'] = (results['inserted'] ?? 0) + 1;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Importación completada: '
                  '${results['inserted']} nuevos, ${results['updated']} actualizados.',
            ),
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint('❌ Error importando Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error importando: $e')));
      }
      return results;
    }
  }
}
