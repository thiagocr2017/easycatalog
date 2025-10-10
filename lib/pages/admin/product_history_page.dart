import 'package:flutter/material.dart';
import '../../data/database_helper.dart';

class ProductHistoryPage extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductHistoryPage({super.key, required this.productId, required this.productName});

  @override
  State<ProductHistoryPage> createState() => _ProductHistoryPageState();
}

class _ProductHistoryPageState extends State<ProductHistoryPage> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final data = await _db.getProductLogs(widget.productId);
    setState(() => _logs = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historial de ${widget.productName}')),
      body: _logs.isEmpty
          ? const Center(child: Text('Sin registros disponibles'))
          : ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          final date = DateTime.tryParse(log['timestamp']) ?? DateTime.now();
          final formatted =
              '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
          final isDepleted = log['action'] == 'agotado';
          return ListTile(
            leading: Icon(
              isDepleted ? Icons.remove_circle : Icons.check_circle,
              color: isDepleted ? Colors.red : Colors.green,
            ),
            title: Text(
              log['action'] == 'agotado'
                  ? 'Marcado como agotado'
                  : 'Reactivado',
            ),
            subtitle: Text(formatted),
          );
        },
      ),
    );
  }
}
