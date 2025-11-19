import 'package:flutter/material.dart';
import 'package:gastos/db.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  Map<String, dynamic>? _selectedAccount;
  List<Map<String, dynamic>> _accounts = [];

  final List<String> _categories = [
    'Comida',
    'Transporte',
    'Ocio',
    'Hogar',
    'Salud',
    'Educación',
    'Otros'
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final db = await DbConnection.instance;
    final accounts = await db.collection('accounts').find().toList();
    setState(() {
      _accounts = accounts;
    });
  }

  Future<void> _saveExpense() async {
    if (_nameController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedAccount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos, incluyendo la cuenta')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduce un monto válido')),
      );
      return;
    }

    try {
      final db = await DbConnection.instance;
      
      // 1. Save the expense
      final collection = db.collection('gastos');
      await collection.insertOne({
        'name': _nameController.text,
        'amount': amount,
        'category': _selectedCategory,
        'accountId': _selectedAccount!['_id'], // Link expense to account
        'timestamp': DateTime.now(),
        'month': DateTime.now().month,
        'year': DateTime.now().year,
      });

      // 2. Update account balance
      await db.collection('accounts').update(
        mongo.where.eq('_id', _selectedAccount!['_id']),
        mongo.modify.inc('balance', -amount), // Decrease balance
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el gasto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Gasto'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del gasto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: r'$',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text('Selecciona una categoría'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
            ),
            const SizedBox(height: 16.0),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedAccount,
              hint: const Text('Selecciona cuenta de pago'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: _accounts.map((Map<String, dynamic> account) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: account,
                  child: Text('${account['name']} (\$${account['balance']})'),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedAccount = newValue;
                });
              },
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: _saveExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
