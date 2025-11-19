import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gastos/db.dart';
import 'package:gastos/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:provider/provider.dart';

class ManageAccountsPage extends StatefulWidget {
  const ManageAccountsPage({super.key});

  @override
  State<ManageAccountsPage> createState() => _ManageAccountsPageState();
}

class _ManageAccountsPageState extends State<ManageAccountsPage> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
    });
    final db = await DbConnection.instance;
    final accounts = await db.collection('accounts').find().toList();
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  Future<void> _addAccount(String name, double balance) async {
    final db = await DbConnection.instance;
    await db.collection('accounts').insertOne({
      'name': name,
      'balance': balance,
      'icon': 'wallet', // Default icon identifier
    });
    _loadAccounts();
  }

  Future<void> _updateAccountBalance(mongo.ObjectId id, double newBalance) async {
    final db = await DbConnection.instance;
    await db.collection('accounts').update(
      mongo.where.eq('_id', id),
      mongo.modify.set('balance', newBalance),
    );
    _loadAccounts();
  }

  Future<void> _deleteAccount(mongo.ObjectId id) async {
    final db = await DbConnection.instance;
    await db.collection('accounts').deleteOne(mongo.where.eq('_id', id));
    _loadAccounts();
  }

  void _showAccountDialog({Map<String, dynamic>? account}) {
    final isEditing = account != null;
    final nameController = TextEditingController(text: isEditing ? account['name'] : '');
    final balanceController = TextEditingController(text: isEditing ? account['balance'].toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Cuenta' : 'Nueva Cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEditing) // Don't allow name change for simplicity, or allow it if desired
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre de la cuenta'),
              ),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Saldo Actual', prefixText: '\$'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text;
              final balance = double.tryParse(balanceController.text) ?? 0.0;

              if (name.isNotEmpty) {
                if (isEditing) {
                  _updateAccountBalance(account['_id'], balance);
                } else {
                  _addAccount(name, balance);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
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
        title: const Text('Administrar Cuentas'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FontAwesomeIcons.wallet, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No tienes cuentas registradas.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showAccountDialog(),
                        child: const Text('Crear primera cuenta'),
                      )
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    return ListTile(
                      leading: const Icon(FontAwesomeIcons.wallet, color: Colors.blue),
                      title: Text(account['name'] ?? 'Cuenta'),
                      subtitle: Text('Saldo: ${currencyFormatter.format(account['balance'] ?? 0)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueGrey),
                            onPressed: () => _showAccountDialog(account: account),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Eliminar Cuenta'),
                                  content: Text('¿Estás seguro de eliminar la cuenta "${account['name']}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                _deleteAccount(account['_id']);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(),
                ),
      floatingActionButton: _accounts.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAccountDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
