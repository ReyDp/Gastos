import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gastos/db.dart';
import 'package:gastos/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

enum ChartView { annual, monthly, weekly }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final currencyFormatter =
      NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
  late Future<Map<String, dynamic>> _financialDataFuture;
  late ChartView _currentView;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      _currentView = _getViewFromString(settingsProvider.defaultChartView);
      _loadData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  void _loadData() {
    _financialDataFuture = _getFinancialData(_currentView);
    setState(() {});
  }

  ChartView _getViewFromString(String view) {
    switch (view) {
      case 'monthly':
        return ChartView.monthly;
      case 'weekly':
        return ChartView.weekly;
      case 'annual':
      default:
        return ChartView.annual;
    }
  }

  Future<Map<String, dynamic>> _getFinancialData(ChartView view) async {
    final db = await DbConnection.instance;
    final now = DateTime.now();
    
    DateTime startDate;
    DateTime endDate;
    
    if (view == ChartView.monthly) {
       startDate = DateTime(now.year, now.month, 1);
       endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (view == ChartView.weekly) {
       startDate = now.subtract(Duration(days: now.weekday - 1));
       startDate = DateTime(startDate.year, startDate.month, startDate.day);
       endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    } else {
       startDate = DateTime(now.year, 1, 1);
       endDate = DateTime(now.year, 12, 31, 23, 59, 59);
    }

    final query = mongo.where.gte('timestamp', startDate).lte('timestamp', endDate);
    
    final expenses = await db.collection('gastos').find(query).toList();
    final extraIncomes = await db.collection('extra_incomes').find(query).toList();
    final userProfile = await db.collection('user_profile').findOne(mongo.where.eq('userId', 1));
    
    final Map<int, Map<String, double>> chartData = {};
    final Map<String, double> expensesByCategory = {};
    double totalIncome = 0;
    double totalExpenses = 0;
    double totalExtraIncome = 0;

    int maxPoints = 0;
    if (view == ChartView.annual) {
      maxPoints = 12;
    } else if (view == ChartView.monthly) {
      maxPoints = DateTime(now.year, now.month + 1, 0).day; 
    } else {
      maxPoints = 7; 
    }

    for (int i = 1; i <= maxPoints; i++) {
      chartData[i] = {'expenses': 0.0, 'extra_income': 0.0, 'income': 0.0, 'balance': 0.0};
      
      if (view == ChartView.annual) {
         final monthlyInc = (userProfile?['financials']?[now.year.toString()]?[i.toString()]?['monthly_income'] as num?)?.toDouble() ?? 0.0;
         chartData[i]!['income'] = monthlyInc;
         totalIncome += monthlyInc;
      }
    }
    
    if (view == ChartView.monthly) {
       final monthlyInc = (userProfile?['financials']?[now.year.toString()]?[now.month.toString()]?['monthly_income'] as num?)?.toDouble() ?? 0.0;
       totalIncome += monthlyInc;
    }

    for (var expense in expenses) {
      final date = expense['timestamp'] as DateTime;
      final amount = (expense['amount'] as num).toDouble();
      final category = expense['category'] as String;
      
      int key = 0;
      if (view == ChartView.annual) key = date.month;
      else if (view == ChartView.monthly) key = date.day;
      else if (view == ChartView.weekly) key = date.weekday;

      if (chartData.containsKey(key)) {
        chartData[key]!['expenses'] = (chartData[key]!['expenses'] ?? 0) + amount;
      }
      
      expensesByCategory[category] = (expensesByCategory[category] ?? 0) + amount;
      totalExpenses += amount;
    }

    for (var income in extraIncomes) {
      final date = income['timestamp'] as DateTime;
      final amount = (income['amount'] as num).toDouble();
      
      int key = 0;
      if (view == ChartView.annual) key = date.month;
      else if (view == ChartView.monthly) key = date.day;
      else if (view == ChartView.weekly) key = date.weekday;

      if (chartData.containsKey(key)) {
        chartData[key]!['extra_income'] = (chartData[key]!['extra_income'] ?? 0) + amount;
      }
      
      totalExtraIncome += amount;
    }

    chartData.forEach((key, value) {
      value['balance'] = (value['income']!) + (value['extra_income']!) - (value['expenses']!);
    });
    
    double totalBalance = totalIncome + totalExtraIncome - totalExpenses;

    return {
      'chartData': chartData,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'totalExtraIncome': totalExtraIncome,
      'totalBalance': totalBalance,
      'expensesByCategory': expensesByCategory,
      'view': view,
    };
  }

  Future<void> _generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(child: pw.Text('Reporte PDF en construcción')),
      )
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'reporte.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final data = await _financialDataFuture;
              _generatePdf(data);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SegmentedButton<ChartView>(
              segments: const [
                ButtonSegment(value: ChartView.weekly, label: Text('Semanal')),
                ButtonSegment(value: ChartView.monthly, label: Text('Mensual')),
                ButtonSegment(value: ChartView.annual, label: Text('Anual')),
              ],
              selected: {_currentView},
              onSelectionChanged: (Set<ChartView> newSelection) {
                setState(() {
                  _currentView = newSelection.first;
                  _loadData();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _financialDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay datos para mostrar.'));
                }

                final data = snapshot.data!;
                final chartData = data['chartData'] as Map<int, Map<String, double>>;
                final expensesByCategory = data['expensesByCategory'] as Map<String, double>;
                final view = data['view'] as ChartView;

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resumen', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Ingreso Total:'), Text(currencyFormatter.format(data['totalIncome']))]),
                                const SizedBox(height: 8),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Ingresos Extra:'), Text(currencyFormatter.format(data['totalExtraIncome']))]),
                                const SizedBox(height: 8),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Gastos Totales:'), Text(currencyFormatter.format(data['totalExpenses']))]),
                                const Divider(height: 20, thickness: 1),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Balance Total:', style: TextStyle(fontWeight: FontWeight.bold)), Text(currencyFormatter.format(data['totalBalance']), style: TextStyle(fontWeight: FontWeight.bold, color: data['totalBalance'] >= 0 ? Colors.green : Colors.red))]),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Balance (${view.name})', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              barGroups: chartData.entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [BarChartRodData(toY: entry.value['expenses'] ?? 0, color: Colors.red, width: view == ChartView.monthly ? 6 : 15)],
                                );
                              }).toList(),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      int idx = value.toInt();
                                      if (view == ChartView.annual) {
                                         const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                                         if (idx >= 1 && idx <= 12) return Text(months[idx - 1], style: const TextStyle(fontSize: 10));
                                      } else if (view == ChartView.weekly) {
                                         const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                                         if (idx >= 1 && idx <= 7) return Text(days[idx - 1], style: const TextStyle(fontSize: 10));
                                      } else if (view == ChartView.monthly) {
                                         if (idx % 5 == 0 || idx == 1) return Text(idx.toString(), style: const TextStyle(fontSize: 10));
                                      }
                                      return const Text('');
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Gastos por Categoría', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (expensesByCategory.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: expensesByCategory.entries.map((entry) {
                                return PieChartSectionData(
                                  value: entry.value,
                                  title: entry.key,
                                  color: Colors.primaries[expensesByCategory.keys.toList().indexOf(entry.key) % Colors.primaries.length],
                                  radius: 50,
                                );
                              }).toList(),
                            ),
                          ),
                        ) else const Text('No hay gastos para mostrar en este periodo.'),
                      ],
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
