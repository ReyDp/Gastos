import 'package:flutter/material.dart';
import 'package:gastos/db.dart';
import 'package:gastos/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:provider/provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _getHistory();
  }

  Future<List<Map<String, dynamic>>> _getHistory() async {
    final db = await DbConnection.instance;
    final expenses = await db.collection('gastos').find().toList();
    final extraIncomes = await db.collection('extra_incomes').find().toList();

    final allTransactions = [...expenses, ...extraIncomes];

    allTransactions.sort((a, b) {
      final dateA = a['timestamp'] as DateTime;
      final dateB = b['timestamp'] as DateTime;
      return dateB.compareTo(dateA); // Sort in descending order
    });

    return allTransactions;
  }

  (String, String) _getCurrencyFormatting(String currencyCode) {
    String locale;
    String symbol;

    switch (currencyCode) {
      case 'USD':
        locale = 'en_US';
        symbol = r'$';
        break;
      case 'EUR':
        locale = 'de_DE';
        symbol = '€';
        break;
      case 'COP':
      default:
        locale = 'es_CO';
        symbol = r'$';
        break;
    }
    return (locale, symbol);
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final (locale, symbol) = _getCurrencyFormatting(settingsProvider.currency);
    final currencyFormatter = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 0);
    final dateFormat = DateFormat(settingsProvider.dateFormat, locale);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay movimientos registrados.'));
          }

          final history = snapshot.data!;

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final isExpense = item.containsKey('category');
              final amount = (item['amount'] as num).toDouble();
              final description = item['name'] ?? item['description'] ?? 'Sin descripción';
              final date = item['timestamp'] as DateTime;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ListTile(
                  leading: Icon(
                    isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isExpense ? Colors.red : Colors.green,
                  ),
                  title: Text(description),
                  subtitle: Text(dateFormat.format(date)),
                  trailing: Text(
                    '${isExpense ? '-' : '+'}${currencyFormatter.format(amount)}',
                    style: TextStyle(
                      color: isExpense ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
