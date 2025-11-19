import 'package:flutter/material.dart';
import 'package:gastos/data_management_page.dart';
import 'package:gastos/manage_accounts_page.dart';
import 'package:gastos/providers/settings_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _budgetController;

  @override
  void initState() {
    super.initState();
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _budgetController = TextEditingController(text: settingsProvider.defaultBudget.toString());
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context, SettingsProvider settingsProvider) async {
    final currentTime = TimeOfDay(
      hour: int.parse(settingsProvider.dailyReminderTime.split(':')[0]),
      minute: int.parse(settingsProvider.dailyReminderTime.split(':')[1]),
    );
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (picked != null && picked != currentTime) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      settingsProvider.setDailyReminderTime(formattedTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return ListView(
            children: [
              ListTile(
                title: const Text('Tema de la Aplicación'),
                trailing: DropdownButton<ThemeMode>(
                  value: settingsProvider.themeMode,
                  onChanged: (ThemeMode? newValue) {
                    if (newValue != null) {
                      settingsProvider.setThemeMode(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Sistema'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Claro'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Oscuro'),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Símbolo de la Moneda'),
                trailing: DropdownButton<String>(
                  value: settingsProvider.currency,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      settingsProvider.setCurrency(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'COP',
                      child: Text('COP'),
                    ),
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('USD'),
                    ),
                    DropdownMenuItem(
                      value: 'EUR',
                      child: Text('EUR'),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Presupuesto Predeterminado'),
                trailing: SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _budgetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      final newBudget = double.tryParse(value);
                      if (newBudget != null) {
                        settingsProvider.setDefaultBudget(newBudget);
                      }
                    },
                  ),
                ),
              ),
              ListTile(
                title: const Text('Página de Inicio'),
                trailing: DropdownButton<String>(
                  value: settingsProvider.defaultHomePage,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      settingsProvider.setDefaultHomePage(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'main',
                      child: Text('Página Principal'),
                    ),
                    DropdownMenuItem(
                      value: 'add',
                      child: Text('Añadir Gasto'),
                    ),
                    DropdownMenuItem(
                      value: 'dashboard',
                      child: Text('Dashboard'),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Formato de Fecha'),
                trailing: DropdownButton<String>(
                  value: settingsProvider.dateFormat,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      settingsProvider.setDateFormat(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'dd/MM/yyyy',
                      child: Text('DD/MM/YYYY'),
                    ),
                    DropdownMenuItem(
                      value: 'MM/dd/yyyy',
                      child: Text('MM/DD/YYYY'),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Día de Corte de Ciclo'),
                trailing: DropdownButton<int>(
                  value: settingsProvider.cycleDay,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      settingsProvider.setCycleDay(newValue);
                    }
                  },
                  items: List.generate(30, (index) => index + 1)
                      .map((day) => DropdownMenuItem(
                            value: day,
                            child: Text(day.toString()),
                          ))
                      .toList(),
                ),
              ),
              ListTile(
                title: const Text('Vista de Gráficos Predeterminada'),
                trailing: DropdownButton<String>(
                  value: settingsProvider.defaultChartView,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      settingsProvider.setDefaultChartView(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'annual',
                      child: Text('Anual'),
                    ),
                    DropdownMenuItem(
                      value: 'monthly',
                      child: Text('Mensual'),
                    ),
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Semanal'),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Administrar Cuentas'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageAccountsPage()),
                  );
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Notificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SwitchListTile(
                title: const Text('Activar Recordatorios Diarios'),
                value: settingsProvider.areNotificationsEnabled,
                onChanged: (bool value) {
                  settingsProvider.setNotificationsEnabled(value);
                },
              ),
              ListTile(
                title: const Text('Hora del Recordatorio'),
                subtitle: Text(settingsProvider.dailyReminderTime),
                trailing: const Icon(Icons.access_time),
                enabled: settingsProvider.areNotificationsEnabled,
                onTap: () => _selectTime(context, settingsProvider),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Datos y Seguridad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Gestión de Datos'),
                subtitle: const Text('Exportar, importar y restablecer'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DataManagementPage()),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
