import 'package:flutter/material.dart';
import 'package:gastos/db.dart';
import 'package:gastos/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:provider/provider.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<Map<String, dynamic>> _financialsFuture;
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _loadData();
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  void _loadData() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _financialsFuture = _getFinancials(settingsProvider);
    setState(() {});
  }

  Future<Map<String, dynamic>> _getFinancials(
      SettingsProvider settingsProvider) async {
    final db = await DbConnection.instance;
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    final profileFuture =
        db.collection('user_profile').findOne(mongo.where.eq('userId', 1));
    final extraIncomesFuture = db
        .collection('extra_incomes')
        .find(mongo.where.eq('month', month).eq('year', year))
        .toList();

    final results = await Future.wait([profileFuture, extraIncomesFuture]);

    final profile = results[0] as Map<String, dynamic>?;
    final extraIncomes = results[1] as List<Map<String, dynamic>>;

    final monthlyData = profile?['financials']?[year.toString()]?[month.toString()];
    final income = (monthlyData?['monthly_income'] as num?)?.toDouble() ?? 0.0;
    var budget = (monthlyData?['monthly_budget'] as num?)?.toDouble() ?? 0.0;

    if (budget == 0.0 && settingsProvider.defaultBudget > 0.0) {
      budget = settingsProvider.defaultBudget;
      await _updateMonthlyFinance('monthly_budget', budget, reload: false);
    }

    if (income == 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showEditDialog(
            title: 'Ingreso Mensual Principal',
            currentValue: 0.0,
            field: 'monthly_income',
            isInitial: true,
          );
        }
      });
    }

    return {
      'profile': profile,
      'extraIncomes': extraIncomes,
      'income': income,
      'budget': budget,
    };
  }

  Future<void> _updateMonthlyFinance(String field, double value, {bool reload = true}) async {
    final db = await DbConnection.instance;
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString();

    await db.collection('user_profile').updateOne(
          mongo.where.eq('userId', 1),
          mongo.modify.set('financials.$year.$month.$field', value),
          upsert: true,
        );
    if (mounted && reload) {
      _loadData();
    }
  }

  Future<void> _deleteExtraIncome(mongo.ObjectId id) async {
    final db = await DbConnection.instance;
    await db.collection('extra_incomes').deleteOne(mongo.where.eq('_id', id));
    if (mounted) {
      _loadData();
    }
  }

  void _showEditDialog(
      {required String title,
      required double currentValue,
      required String field,
      bool isInitial = false}) {
    final controller =
        TextEditingController(text: currentValue != 0 ? currentValue.toString() : '');
    showDialog(
      context: context,
      barrierDismissible: !isInitial,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: r'$'),
          autofocus: true,
        ),
        actions: [
          if (!isInitial)
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(controller.text);
              if (newAmount != null) {
                _updateMonthlyFinance(field, newAmount);
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAddExtraIncomeDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Ingreso Extra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Descripción')),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Monto', prefixText: r'$'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (descController.text.isNotEmpty && amount != null) {
                final db = await DbConnection.instance;
                await db.collection('extra_incomes').insertOne({
                  'description': descController.text,
                  'amount': amount,
                  'month': DateTime.now().month,
                  'year': DateTime.now().year,
                  'timestamp': DateTime.now(),
                });
                if (mounted) {
                  _loadData();
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Billetera'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _financialsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Expanded(
                      child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('No hay datos de perfil.'));
                }

                final data = snapshot.data!;
                final income = data['income'] as double;
                final budget = data['budget'] as double;
                final extraIncomes =
                    data['extraIncomes'] as List<Map<String, dynamic>>;

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ingreso Mensual Principal',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          onTap: () => _showEditDialog(
                              title: 'Editar Ingreso Mensual',
                              currentValue: income,
                              field: 'monthly_income'),
                          leading: const Icon(Icons.monetization_on_outlined,
                              color: Colors.green),
                          title: Text(currencyFormatter.format(income),
                              style: const TextStyle(fontSize: 20)),
                          trailing: const Icon(Icons.edit, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Presupuesto Mensual',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          onTap: () => _showEditDialog(
                              title: 'Editar Presupuesto Mensual',
                              currentValue: budget,
                              field: 'monthly_budget'),
                          leading: const Icon(Icons.shield_outlined,
                              color: Colors.blue),
                          title: Text(currencyFormatter.format(budget),
                              style: const TextStyle(fontSize: 20)),
                          trailing: const Icon(Icons.edit, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Ingresos Extra Este Mes',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: extraIncomes.length,
                          itemBuilder: (context, index) {
                            final extraIncome = extraIncomes[index];
                            return Dismissible(
                              key: Key(extraIncome['_id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20.0),
                                child:
                                    const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text("Confirmar"),
                                      content: const Text(
                                          "¿Estás seguro de que quieres eliminar este ingreso?"),
                                      actions: <Widget>[
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                            child: const Text("CANCELAR")),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text("ELIMINAR")),
                                      ],
                                    );
                                  },
                                );
                              },
                              onDismissed: (direction) {
                                _deleteExtraIncome(extraIncome['_id']);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                        content: Text(
                                            "${extraIncome['description']} eliminado")));
                              },
                              child: Card(
                                child: ListTile(
                                  leading: const Icon(Icons.add_card,
                                      color: Colors.orange),
                                  title: Text(
                                      extraIncome['description'] ?? 'Sin descripción'),
                                  trailing: Text(
                                    '+${currencyFormatter.format(extraIncome['amount'])}',
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExtraIncomeDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
