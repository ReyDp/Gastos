import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:gastos/db.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final LocalAuthentication auth = LocalAuthentication();

  // MongoDB Authentication
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final db = await DbConnection.instance;
      final collection = db.collection('users');

      // Hash password
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes);
      var passwordHash = digest.toString();

      final user = await collection.findOne({
        'email': email,
        'password': passwordHash,
      });

      if (user != null) {
         // Store user session (simple version)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user['_id'].toString());
        return user;
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<bool> signup(String email, String password, String name) async {
    try {
      final db = await DbConnection.instance;
      final collection = db.collection('users');

      final existingUser = await collection.findOne({'email': email});
      if (existingUser != null) {
        return false; // User already exists
      }

      // Hash password
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes);
      var passwordHash = digest.toString();

      // Create new user
      // Generate a new UUID or simple ID. For simplicity, we use ObjectId
      final newId = ObjectId();
      
      await collection.insert({
        '_id': newId,
        'email': email,
        'password': passwordHash,
        'name': name,
        'createdAt': DateTime.now(),
      });

      // Create initial profile for the user
      await db.collection('user_profile').insert({
        'userId': newId.toHexString(), // Storing as String for easier querying later
        'name': name,
        'email': email,
        'financials': {}
      });
      
      return true;
    } catch (e) {
      print('Signup error: $e');
      return false;
    }
  }
  
  Future<void> logout() async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('userId');
  }

  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }


  // Biometric Authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Por favor autentícate para acceder a Gastos',
      );
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
