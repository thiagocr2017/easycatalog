import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/database_helper.dart';
import '../../models/product.dart';
import '../../services/pdf_service.dart';
import '../catalog/pdf_preview_page.dart';

class DepletedProductsPage extends StatefulWidget {
  const DepletedProductsPage({super.key});

  @override
  State<DepletedProductsPage> createState() => _DepletedProductsPageState();
}

class _DepletedProductsPageState extends State<DepletedProductsPage> {
  final _db = DatabaseHelper.instance;
  final _pdfService = PdfService();

  List<Product> _allDepleted = [];
  List<Product> _filteredDepleted = [];

  String _searchQuery = '';
  String _filterOption = 'Todos';
  String _orderOption = 'Más recientes primero';

  @override
  void initState() {
    super.initState();
    _loadDepleted();
  }

  Future<void> _loadDepleted() async {
    final data = await _db.getProducts();
    final depleted = data
        .map((e) => Product.fromMap(e))
        .where((p) => p.isDepleted)
        .toList();

    setState(() {
      _allDepleted = depleted;
      _applyFilters();
    });
  }

  // 🔍 Aplicar búsqueda, filtros y orden
  void _applyFilters() {
    List<Product> result = List.from(_allDepleted);

    // Búsqueda por texto
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((p) =>
      p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Filtro por rango temporal
    if (_filterOption != 'Todos') {
      final now = DateTime.now();

      bool matches(Product p) {
        final d = DateTime.tryParse(p.depletedAt ?? '');
        if (d == null) return false;
        final diff = now.difference(d).inDays;

        switch (_filterOption) {
          case 'Últimos 7 días':
            return diff <= 7;
          case 'Últimos 30 días':
            return diff <= 30;
          case 'Hace un mes':
            return diff > 30 && diff <= 60;
          case 'Hace un trimestre':
            return diff > 60 && diff <= 120;
          case 'Hace un semestre':
            return diff > 120 && diff <= 240;
          case 'Hace un año':
            return diff > 240 && diff <= 365;
          case 'Hace más de un año':
            return diff > 365;
          default:
            return true;
        }
      }

      result = result.where(matches).toList();
    }

    // Ordenar
    result.sort((a, b) {
      final da = DateTime.tryParse(a.depletedAt ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b.depletedAt ?? '') ?? DateTime(2000);
      return _orderOption == 'Más recientes primero'
          ? db.compareTo(da)
          : da.compareTo(db);
    });

    setState(() {
      _filteredDepleted = result;
    });
  }

  Future<void> _reactivateProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivar producto'),
        content: Text('¿Seguro que deseas reactivar "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, reactivar')),
        ],
      ),
    );

    if (confirmed != true) return;

    final updated = p.toMap();
    updated['isDepleted'] = 0;
    updated['depletedAt'] = null;
    await _db.updateProduct(updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Producto "${p.name}" reactivado')),
    );

    _loadDepleted();
  }

  void _previewPdf() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewPage(
          customBuilder: (format) async =>
          await _pdfService.buildDepletedProductsReport(_filteredDepleted),
          title: 'Vista previa de productos agotados',
          fileName: 'productos_agotados.pdf',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos Agotados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Vista previa PDF',
            onPressed: _filteredDepleted.isEmpty ? null : _previewPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔎 Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (text) {
                _searchQuery = text;
                _applyFilters();
              },
            ),
          ),

          // 🔽 Filtros superiores
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Filtro de tiempo
                  Row(
                    children: [
                      const Text('Mostrar: '),
                      DropdownButton<String>(
                        value: _filterOption,
                        items: const [
                          DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                          DropdownMenuItem(value: 'Últimos 7 días', child: Text('Últimos 7 días')),
                          DropdownMenuItem(value: 'Últimos 30 días', child: Text('Últimos 30 días')),
                          DropdownMenuItem(value: 'Hace un mes', child: Text('Hace un mes')),
                          DropdownMenuItem(value: 'Hace un trimestre', child: Text('Hace un trimestre')),
                          DropdownMenuItem(value: 'Hace un semestre', child: Text('Hace un semestre')),
                          DropdownMenuItem(value: 'Hace un año', child: Text('Hace un año')),
                          DropdownMenuItem(value: 'Hace más de un año', child: Text('Hace más de un año')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _filterOption = value);
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),

                  // Orden asc/desc
                  Row(
                    children: [
                      const Text('Ordenar: '),
                      DropdownButton<String>(
                        value: _orderOption,
                        items: const [
                          DropdownMenuItem(value: 'Más recientes primero', child: Text('Más recientes')),
                          DropdownMenuItem(value: 'Más antiguos primero', child: Text('Más antiguos')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _orderOption = value);
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // 📋 Lista filtrada
          Expanded(
            child: _filteredDepleted.isEmpty
                ? const Center(child: Text('No hay productos que coincidan'))
                : ListView.builder(
              itemCount: _filteredDepleted.length,
              itemBuilder: (context, i) {
                final p = _filteredDepleted[i];
                final date = DateTime.tryParse(p.depletedAt ?? '');
                final formatted = date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : '';
                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: p.imagePath != null &&
                        File(p.imagePath!).existsSync()
                        ? Image.file(File(p.imagePath!),
                        width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported),
                    title: Text(p.name),
                    subtitle: Text(
                      '${p.description}\nPrecio: \$${p.price.toStringAsFixed(2)}\nAgotado: $formatted',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.restore_outlined,
                          color: Colors.green),
                      tooltip: 'Reactivar producto',
                      onPressed: () => _reactivateProduct(p),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
