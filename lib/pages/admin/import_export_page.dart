import 'package:flutter/material.dart';
import '../../services/import_export_service.dart';

class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key});

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  final _service = ImportExportService();

  bool _isProcessing = false;
  String _statusMessage = '';
  int _inserted = 0;
  int _updated = 0;
  int _exported = 0;
  bool _hasError = false;

  // ─────────────────────────────────────────────
  // 📤 EXPORTAR
  // ─────────────────────────────────────────────
  Future<void> _exportExcel() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Exportando productos a Excel...';
      _hasError = false;
      _inserted = 0;
      _updated = 0;
      _exported = 0;
    });

    try {
      final file = await _service.exportToExcel(context);
      if (file != null) {
        setState(() {
          _exported = 1; // se generó 1 archivo
          _statusMessage = '✅ Exportación completada correctamente.';
        });
      } else {
        setState(() {
          _hasError = true;
          _statusMessage = '⚠️ Exportación cancelada.';
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusMessage = '❌ Error al exportar: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ─────────────────────────────────────────────
  // 📥 IMPORTAR (usa resultados reales del servicio)
  // ─────────────────────────────────────────────
  Future<void> _importExcel() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Importando datos desde Excel...';
      _hasError = false;
      _inserted = 0;
      _updated = 0;
      _exported = 0;
    });

    try {
      // ✅ Llama al servicio y obtiene el mapa con resultados reales
      final results = await _service.importFromExcel(context);

      setState(() {
        _inserted = results['inserted'] ?? 0;
        _updated = results['updated'] ?? 0;
        _statusMessage =
        '✅ Importación completada ($_inserted nuevos, $_updated actualizados)';
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusMessage = '❌ Error durante la importación: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ─────────────────────────────────────────────
  // 🧱 INTERFAZ PRINCIPAL
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar / Exportar Catálogo'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Administra tu catálogo completo de productos en formato Excel.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),

              // 🧾 EXPORTAR
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.upload_file_outlined,
                          size: 60, color: Colors.green),
                      const SizedBox(height: 10),
                      const Text(
                        'Exportar catálogo a Excel',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Genera un archivo Excel con todos los productos y secciones actuales.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Exportar a Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                        ),
                        onPressed: _isProcessing ? null : _exportExcel,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 📥 IMPORTAR
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.download_outlined,
                          size: 60, color: Colors.blue),
                      const SizedBox(height: 10),
                      const Text(
                        'Importar catálogo desde Excel',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Carga un archivo Excel para crear o actualizar productos en masa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Importar desde Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                        ),
                        onPressed: _isProcessing ? null : _importExcel,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 🔄 Indicador de progreso
              if (_isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.black54),
                ),
              ] else if (_statusMessage.isNotEmpty) ...[
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _hasError ? Colors.red : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // 📊 Resultados visuales
              if (!_isProcessing &&
                  (_inserted > 0 || _updated > 0 || _exported > 0))
                Card(
                  color: Colors.grey.shade100,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      const ListTile(
                        title: Text(
                          'Resumen de la última operación',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        leading: Icon(Icons.assessment_outlined),
                      ),
                      if (_exported > 0)
                        const ListTile(
                          leading: Icon(Icons.file_present_outlined,
                              color: Colors.green),
                          title: Text('Catálogo exportado'),
                          subtitle: Text(
                              'Archivo Excel generado correctamente.'),
                        ),
                      if (_inserted > 0)
                        ListTile(
                          leading: const Icon(Icons.add_circle_outline,
                              color: Colors.blue),
                          title: Text('$_inserted productos nuevos'),
                          subtitle: const Text(
                              'Importados desde el archivo Excel.'),
                        ),
                      if (_updated > 0)
                        ListTile(
                          leading: const Icon(Icons.update,
                              color: Colors.orange),
                          title: Text('$_updated productos actualizados'),
                          subtitle: const Text(
                              'Datos actualizados en la base existente.'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
