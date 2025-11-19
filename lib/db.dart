import 'package:mongo_dart/mongo_dart.dart' hide State, Size, Center;

class DbConnection {
  static Db? _db;

  static const String _connectionString =
      "mongodb+srv://reinaldo0602_db_user:EPqq17UXqsPDU0Xy@cluster0.ri8nyxu.mongodb.net/gastos?appName=Cluster0";

  static Future<Db> get instance async {
    if (_db == null || !_db!.isConnected) {
      await _connect();
    }
    return _db!;
  }

  static Future<void> _connect() async {
    try {
      _db = await Db.create(_connectionString);
      await _db!.open();
      print('✅ Conexión con MongoDB establecida');
    } catch (e) {
      print('❌ Error al conectar con MongoDB: $e');
    }
  }

  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      print('🔌 Conexión con MongoDB cerrada');
    }
  }
}
