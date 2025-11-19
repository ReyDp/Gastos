import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gastos/add_expense_page.dart';
import 'package:gastos/dashboard_page.dart';
import 'package:gastos/db.dart';
import 'package:gastos/edit_expense_page.dart';
import 'package:gastos/graph_widget.dart';
import 'package:gastos/history_page.dart';
import 'package:gastos/login_page.dart';
import 'package:gastos/providers/settings_provider.dart';
import 'package:gastos/services/auth_service.dart';
import 'package:gastos/services/notification_service.dart';
import 'package:gastos/settings_page.dart';
import 'package:gastos/wallet_page.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

class FinancialSummary {
  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> extraIncomes;

  FinancialSummary(this.userProfile, this.expenses, this.extraIncomes);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO', null);
  final notificationService = NotificationService();
  await notificationService.init();
  runApp(ChangeNotifierProvider(
    create: (_) => SettingsProvider(),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return MaterialApp(
          title: 'Control de Gastos',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(),
          themeMode: settingsProvider.themeMode,
          home: const AppInitializer(),
        );
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final authService = AuthService();
    final userId = await authService.getCurrentUserId();
    
    if (mounted) {
      if (userId != null) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        await settingsProvider.setUserId(userId);
      }
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final settingsProvider = Provider.of<SettingsProvider>(context);
    if (settingsProvider.userId == null) {
      return const LoginPage();
    } else {
      return const AuthWrapper();
    }
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;
  bool _checkPerformed = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    if (!settingsProvider.isBiometricEnabled) {
      setState(() {
        _isAuthenticated = true;
        _checkPerformed = true;
      });
      return;
    }

    final authService = AuthService();
    final canCheck = await authService.isBiometricAvailable();
    
    if (!canCheck) {
       // If biometric not available but enabled, fallback to allow or force disable
       // For simplicity, we allow access but you might want to force PIN
       setState(() {
        _isAuthenticated = true;
        _checkPerformed = true;
      });
      return;
    }

    final authenticated = await authService.authenticate();
    setState(() {
      _isAuthenticated = authenticated;
      _checkPerformed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkPerformed) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAuthenticated) {
      return const MyHomePage(title: 'Control de Gasto');
    } else {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text('Aplicación Bloqueada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkAuth,
                child: const Text('Desbloquear'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late PageController _controller;
  int currentPage = DateTime.now().month - 1;
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: currentPage,
      viewportFraction: 0.4,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _checkInitialPage();
      _isInit = false;
    }
  }

  void _checkInitialPage() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final defaultHomePage = settingsProvider.defaultHomePage;

    if (defaultHomePage != 'main') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (defaultHomePage == 'add') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpensePage()),
          );
        } else if (defaultHomePage == 'dashboard') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToEditPage(Map<String, dynamic> expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditExpensePage(expense: expense)),
    );
    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = AuthService();
              await authService.logout();
              
              if (!context.mounted) return;
              
              final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
              await settingsProvider.setUserId(null);
              
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        notchMargin: 8.0,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            IconButton(
                icon: const Icon(FontAwesomeIcons.clockRotateLeft),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HistoryPage()),
                  );
                }),
            IconButton(
                icon: const Icon(FontAwesomeIcons.chartPie),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DashboardPage()),
                  );
                }),
            const SizedBox(width: 48.0),
            IconButton(
              icon: const Icon(FontAwesomeIcons.wallet),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WalletPage()),
                );
                setState(() {});
              },
            ),
            IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                }),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpensePage()),
          );
          if (result == true) {
            setState(() {});
          }
        },
      ),
      body: _body(settingsProvider),
    );
  }

  Widget _body(SettingsProvider settingsProvider) {
    return SafeArea(
      child: Column(
        children: <Widget>[
          _selector(),
          Expanded(
            child: FutureBuilder<FinancialSummary>(
              future: _getFinancialSummary(currentPage + 1, settingsProvider),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final summary = snapshot.data;
                final expenses = summary?.expenses ?? [];
                final profile = summary?.userProfile;
                final year = DateTime.now().year.toString();
                final month = (currentPage + 1).toString();
                final monthlyData = profile?['financials']?[year]?[month];

                final income = (monthlyData?['monthly_income'] as num?)?.toDouble() ?? 0.0;
                final extraIncomesTotal = summary?.extraIncomes.fold<double>(0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0)) ?? 0.0;
                final totalIncome = income + extraIncomesTotal;
                final totalExpenses = expenses.fold<double>(0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0));
                final budget = (monthlyData?['monthly_budget'] as num?)?.toDouble() ?? 0.0;

                return Column(
                  children: [
                    _balance(totalIncome, totalExpenses, budget),
                    _graph(expenses),
                    Container(
                      color: Colors.blueAccent.withOpacity(0.15),
                      height: 24.0,
                    ),
                    _list(expenses),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageItem(String name, int position) {
    var alignment = Alignment.center;
    final selected = const TextStyle(
      fontSize: 20.0,
      fontWeight: FontWeight.bold,
      color: Colors.blueGrey,
    );
    final unselected = TextStyle(
      fontSize: 20.0,
      fontWeight: FontWeight.normal,
      color: Colors.blueGrey.withOpacity(0.4),
    );

    if (position == currentPage) {
      alignment = Alignment.center;
    } else if (position > currentPage) {
      alignment = Alignment.centerRight;
    } else {
      alignment = Alignment.centerLeft;
    }

    return Align(
      alignment: alignment,
      child: Text(
        name,
        style: position == currentPage ? selected : unselected,
      ),
    );
  }

  Widget _selector() {
    return SizedBox.fromSize(
      size: const Size.fromHeight(70.0),
      child: PageView(
        onPageChanged: (newPage) {
          setState(() {
            currentPage = newPage;
          });
        },
        controller: _controller,
        children: <Widget>[
          _pageItem("Enero", 0),
          _pageItem("Febrero", 1),
          _pageItem("Marzo", 2),
          _pageItem("Abril", 3),
          _pageItem("Mayo", 4),
          _pageItem("Junio", 5),
          _pageItem("Julio", 6),
          _pageItem("Agosto", 7),
          _pageItem("Septiembre", 8),
          _pageItem("Octubre", 9),
          _pageItem("Noviembre", 10),
          _pageItem("Diciembre", 11),
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

  Widget _balance(double totalIncome, double totalExpenses, double budget) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final (locale, symbol) = _getCurrencyFormatting(settingsProvider.currency);

    final currencyFormatter = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 0);
    final remainingBalance = totalIncome - totalExpenses;
    final budgetProgress = budget > 0 ? totalExpenses / budget : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text("Saldo del Mes", style: TextStyle(fontSize: 16, color: Colors.grey)),
          Text(currencyFormatter.format(remainingBalance), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text("Presupuesto del Mes", style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: budgetProgress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(budgetProgress > 1 ? Colors.red : Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _graph(List<Map<String, dynamic>> expenses) {
    return SizedBox(
      height: 250.0,
      child: GraphWidget(expenses: expenses),
    );
  }

  Widget _item(Map<String, dynamic> expense) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final (locale, symbol) = _getCurrencyFormatting(settingsProvider.currency);

    final currencyFormatter = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 0);
    return InkWell(
      onTap: () => _navigateToEditPage(expense),
      child: ListTile(
        leading: const Icon(FontAwesomeIcons.cartShopping, size: 32.0),
        title: Text(
          expense['name'] ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        subtitle: Text(
          expense['category'] ?? 'Sin categoría',
          style: const TextStyle(fontSize: 16.0, color: Colors.blueGrey),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(5.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              currencyFormatter.format((expense['amount'] as num?)?.toDouble() ?? 0.0),
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.w500,
                fontSize: 16.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<FinancialSummary> _getFinancialSummary(int month, SettingsProvider settingsProvider) async {
    final db = await DbConnection.instance;
    final year = DateTime.now().year;
    
    if (settingsProvider.userId == null) {
       return FinancialSummary(null, [], []);
    }
    
    // Use dynamic user ID from provider
    final userId = settingsProvider.userId;
    
    DateTime startDate;
    DateTime endDate;

    if (settingsProvider.cycleDay == 1) {
      startDate = DateTime(year, month, 1);
      endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    } else {
      // If cycle day is e.g. 15, and month is May (5)
      // Cycle is from April 15 to May 14
      final prevMonth = month - 1 == 0 ? 12 : month - 1;
      final prevYear = month - 1 == 0 ? year - 1 : year;
      
      startDate = DateTime(prevYear, prevMonth, settingsProvider.cycleDay);
      // End date is the day before the cycle day in the current month
      endDate = DateTime(year, month, settingsProvider.cycleDay).subtract(const Duration(seconds: 1));
    }

    final results = await Future.wait([
      db.collection('user_profile').findOne(mongo.where.eq('userId', userId)),
      db.collection('gastos').find(mongo.where.gte('timestamp', startDate).lte('timestamp', endDate).eq('userId', userId)).toList(),
      db.collection('extra_incomes').find(mongo.where.gte('timestamp', startDate).lte('timestamp', endDate).eq('userId', userId)).toList(),
    ]);

    return FinancialSummary(
      results[0] as Map<String, dynamic>?,
      results[1] as List<Map<String, dynamic>>,
      results[2] as List<Map<String, dynamic>>,
    );
  }

  Widget _list(List<Map<String, dynamic>> expenses) {
    if (expenses.isEmpty) {
      return const Expanded(
        child: Center(child: Text("No hay gastos para este mes.")),
      );
    }

    return Expanded(
      child: ListView.separated(
        itemCount: expenses.length,
        itemBuilder: (BuildContext context, int index) {
          return _item(expenses[index]);
        },
        separatorBuilder: (BuildContext context, int index) {
          return Container(
            color: Colors.blueAccent.withOpacity(0.15),
            height: 8.0,
          );
        },
      ),
    );
  }
}
