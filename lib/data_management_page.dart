import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gastos/db.dart';
import 'package:gastos/providers/settings_provider.dart';
import 'package:gastos/services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool _isLoading = false;

  Future<void> _exportToCSV() async {
    setState(() => _isLoading = true);
    try {
      final db = await DbConnection.instance;
      final expenses = await db.collection('gastos').find().toList();
      final extraIncomes = await db.collection('extra_incomes').find().toList();

      List<List<dynamic>> rows = [];
      rows.add(['Tipo', 'Nombre/Descripcion', 'Monto', 'Categoria', 'Fecha']);

      for (var expense in expenses) {
        rows.add([
          'Gasto',
          expense['name'],
          expense['amount'],
          expense['category'],
          expense['timestamp'].toString()
        ]);
      }

      for (var income in extraIncomes) {
        rows.add([
          'Ingreso',
          income['description'],
          income['amount'],
          'N/A',
          income['timestamp'].toString()
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/transacciones.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: 'Mis transacciones');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        final db = await DbConnection.instance;
        int importedCount = 0;

        // Skip header row (index 0)
        for (var i = 1; i < fields.length; i++) {
          final row = fields[i];
          if (row.length < 5) continue;

          final type = row[0].toString();
          final name = row[1].toString();
          final amount = double.tryParse(row[2].toString()) ?? 0.0;
          final category = row[3].toString();
          final dateString = row[4].toString();
          final date = DateTime.tryParse(dateString) ?? DateTime.now();

          if (type == 'Gasto') {
            await db.collection('gastos').insertOne({
              'name': name,
              'amount': amount,
              'category': category,
              'timestamp': date,
              'month': date.month,
              'year': date.year,
            });
            importedCount++;
          } else if (type == 'Ingreso') {
            await db.collection('extra_incomes').insertOne({
              'description': name,
              'amount': amount,
              'timestamp': date,
              'month': date.month,
              'year': date.year,
            });
            importedCount++;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Se importaron $importedCount registros.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer Datos'),
        content: const Text(
            '¿Estás seguro? Esto borrará TODOS tus gastos, ingresos, cuentas y configuración. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Borrar Todo')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final db = await DbConnection.instance;
        await db.collection('gastos').drop();
        await db.collection('extra_incomes').drop();
        await db.collection('accounts').drop();
        await db.collection('user_profile').drop();
        // Note: We might not want to delete SharedPreferences (settings) or maybe we do.
        // For now, let's keep app settings but clear data.
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos eliminados correctamente.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al restablecer datos: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Datos y Seguridad'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<SettingsProvider>(
              builder: (context, settingsProvider, child) {
                return ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Datos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.file_download),
                      title: const Text('Exportar a CSV'),
                      subtitle: const Text('Guarda tus transacciones en un archivo'),
                      onTap: _exportToCSV,
                    ),
                    ListTile(
                      leading: const Icon(Icons.file_upload),
                      title: const Text('Importar CSV'),
                      subtitle: const Text('Carga transacciones desde un archivo'),
                      onTap: _importFromCSV,
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text('Restablecer Datos', style: TextStyle(color: Colors.red)),
                      subtitle: const Text('Borrar toda la información de la app'),
                      onTap: _resetData,
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Seguridad',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    SwitchListTile(
                      title: const Text('Bloqueo de Aplicación'),
                      subtitle: const Text('Usar biometría para desbloquear'),
                      secondary: const Icon(Icons.lock),
                      value: settingsProvider.isBiometricEnabled,
                      onChanged: (bool value) async {
                        final authService = AuthService();
                        final canCheck = await authService.isBiometricAvailable();
                        
                        if (!canCheck && value) {
                           if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('La biometría no está disponible en este dispositivo.')),
                            );
                          }
                          return;
                        }

                        if (value) {
                           // Enable: Authenticate first to confirm ownership
                           final authenticated = await authService.authenticate();
                           if (authenticated) {
                             settingsProvider.setBiometricEnabled(true);
                           }
                        } else {
                          // Disable: Authenticate first to prevent unauthorized disable
                          final authenticated = await authService.authenticate();
                          if (authenticated) {
                            settingsProvider.setBiometricEnabled(false);
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}
