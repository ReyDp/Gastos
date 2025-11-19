import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _currency = 'COP'; // Default currency
  double _defaultBudget = 0.0;
  String _defaultHomePage = 'main';
  String _dateFormat = 'dd/MM/yyyy';
  int _cycleDay = 1;
  bool _areNotificationsEnabled = false;
  String _dailyReminderTime = '20:00'; // Default 8:00 PM
  bool _isBiometricEnabled = false;
  String _defaultChartView = 'annual';
  String? _userId;

  ThemeMode get themeMode => _themeMode;
  String get currency => _currency;
  double get defaultBudget => _defaultBudget;
  String get defaultHomePage => _defaultHomePage;
  String get dateFormat => _dateFormat;
  int get cycleDay => _cycleDay;
  bool get areNotificationsEnabled => _areNotificationsEnabled;
  String get dailyReminderTime => _dailyReminderTime;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String get defaultChartView => _defaultChartView;
  String? get userId => _userId;

  static const String _themeModeKey = 'themeMode';
  static const String _currencyKey = 'currency'; // Key for storing currency
  static const String _defaultBudgetKey = 'defaultBudget';
  static const String _defaultHomePageKey = 'defaultHomePage';
  static const String _dateFormatKey = 'dateFormat';
  static const String _cycleDayKey = 'cycleDay';
  static const String _notificationsEnabledKey = 'notificationsEnabled';
  static const String _dailyReminderTimeKey = 'dailyReminderTime';
  static const String _biometricEnabledKey = 'biometricEnabled';
  static const String _defaultChartViewKey = 'defaultChartView';
  static const String _userIdKey = 'userId';

  SettingsProvider() {
    _loadThemeMode();
    _loadCurrency(); // Load currency on init
    _loadDefaultBudget();
    _loadDefaultHomePage();
    _loadDateFormat();
    _loadCycleDay();
    _loadNotificationSettings();
    _loadBiometricSettings();
    _loadDefaultChartView();
    _loadUserId();
  }

  void _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeModeKey);
    if (themeModeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeModeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;
    _themeMode = themeMode;
    final prefs = await SharedPreferences.getInstance();
    String themeModeString;
    if (themeMode == ThemeMode.light) {
      themeModeString = 'light';
    } else if (themeMode == ThemeMode.dark) {
      themeModeString = 'dark';
    } else {
      themeModeString = 'system';
    }
    await prefs.setString(_themeModeKey, themeModeString);
    notifyListeners();
  }

  // Method to load currency
  void _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_currencyKey) ?? 'COP'; // Default to COP if not set
    notifyListeners();
  }

  // Method to set and save currency
  void setCurrency(String newCurrency) async {
    if (_currency == newCurrency) return;
    _currency = newCurrency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, newCurrency);
    notifyListeners();
  }

  void _loadDefaultBudget() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultBudget = prefs.getDouble(_defaultBudgetKey) ?? 0.0;
    notifyListeners();
  }

  void setDefaultBudget(double newBudget) async {
    if (_defaultBudget == newBudget) return;
    _defaultBudget = newBudget;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultBudgetKey, newBudget);
    notifyListeners();
  }

  void _loadDefaultHomePage() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultHomePage = prefs.getString(_defaultHomePageKey) ?? 'main';
    notifyListeners();
  }

  void setDefaultHomePage(String newHomePage) async {
    if (_defaultHomePage == newHomePage) return;
    _defaultHomePage = newHomePage;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultHomePageKey, newHomePage);
    notifyListeners();
  }

  void _loadDateFormat() async {
    final prefs = await SharedPreferences.getInstance();
    _dateFormat = prefs.getString(_dateFormatKey) ?? 'dd/MM/yyyy';
    notifyListeners();
  }

  void setDateFormat(String newFormat) async {
    if (_dateFormat == newFormat) return;
    _dateFormat = newFormat;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateFormatKey, newFormat);
    notifyListeners();
  }

  void _loadCycleDay() async {
    final prefs = await SharedPreferences.getInstance();
    _cycleDay = prefs.getInt(_cycleDayKey) ?? 1;
    notifyListeners();
  }

  void setCycleDay(int newDay) async {
    if (_cycleDay == newDay) return;
    _cycleDay = newDay;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cycleDayKey, newDay);
    notifyListeners();
  }

  void _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _areNotificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? false;
    _dailyReminderTime = prefs.getString(_dailyReminderTimeKey) ?? '20:00';
    notifyListeners();
  }

  void setNotificationsEnabled(bool enabled) async {
    if (_areNotificationsEnabled == enabled) return;
    _areNotificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    notifyListeners();
  }

  void setDailyReminderTime(String time) async {
    if (_dailyReminderTime == time) return;
    _dailyReminderTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyReminderTimeKey, time);
    notifyListeners();
  }

  void _loadBiometricSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isBiometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
    notifyListeners();
  }

  void setBiometricEnabled(bool enabled) async {
    if (_isBiometricEnabled == enabled) return;
    _isBiometricEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    notifyListeners();
  }

  void _loadDefaultChartView() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultChartView = prefs.getString(_defaultChartViewKey) ?? 'annual';
    notifyListeners();
  }

  void setDefaultChartView(String newView) async {
    if (_defaultChartView == newView) return;
    _defaultChartView = newView;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultChartViewKey, newView);
    notifyListeners();
  }

  void _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_userIdKey);
    notifyListeners();
  }

  Future<void> setUserId(String? userId) async {
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_userIdKey);
    } else {
      await prefs.setString(_userIdKey, userId);
    }
    notifyListeners();
  }
}
