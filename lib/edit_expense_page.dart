import 'package:flutter/material.dart';
import 'package:gastos/db.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class EditExpensePage extends StatefulWidget {
  final Map<String, dynamic> expense;

  const EditExpensePage({super.key, required this.expense});

  @override
  State<EditExpensePage> createState() => _EditExpensePageState();
}

class _EditExpensePageState extends State<EditExpensePage> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  String? _selectedCategory;

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
    _nameController = TextEditingController(text: widget.expense['name'] ?? '');
    _amountController = TextEditingController(text: (widget.expense['amount'] ?? 0).toString());
    _selectedCategory = widget.expense['category'];
  }

  Future<void> _updateExpense() async {
    if (_nameController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _selectedCategory == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
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
      final collection = db.collection('gastos');

      await collection.updateOne(
        mongo.where.eq('_id', widget.expense['_id']),
        mongo.modify
            .set('name', _nameController.text)
            .set('amount', amount)
            .set('category', _selectedCategory),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el gasto: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Gasto'),
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
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: _updateExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }
}
