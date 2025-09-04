import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

// This provider will manage the single instance of DatabaseService
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class DatabaseService {
  Database? _database;

  // Private constructor for internal use
  DatabaseService._internal();

  // Factory constructor for the singleton instance
  factory DatabaseService() => _instance;
  static final DatabaseService _instance = DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'jwe_pos.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول الفئات
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_ar TEXT NOT NULL,
        icon_name TEXT NOT NULL
      )
    ''');

    // جدول المواد الخام
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_ar TEXT TEXT NOT NULL
      )
    ''');

    // جدول الأصناف
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL UNIQUE,
        category_id INTEGER NOT NULL,
        material_id INTEGER NOT NULL,
        weight_grams REAL NOT NULL,
        karat INTEGER NOT NULL,
        workmanship_fee REAL NOT NULL DEFAULT 0,
        stone_price REAL NOT NULL DEFAULT 0,
        image_path TEXT,
        rfid_tag TEXT UNIQUE,
        status TEXT NOT NULL DEFAULT 'needsRfid',
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (material_id) REFERENCES materials (id)
      )
    ''');

    // جدول العملاء
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول الفواتير
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        subtotal REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        payment_method TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // جدول عناصر الفواتير
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id),
        FOREIGN KEY (item_id) REFERENCES items (id)
      )
    ''');

    // جدول الإعدادات
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // إدراج البيانات الأولية
    await _insertInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // سيتم إضافة منطق الترقية هنا عند الحاجة
  }

  Future<void> _insertInitialData(Database db) async {
    // إدراج فئات افتراضية
    await db.insert('categories', {'name_ar': 'خواتم', 'icon_name': 'ring'});
    await db.insert('categories', {
      'name_ar': 'أساور',
      'icon_name': 'bracelet',
    });
    await db.insert('categories', {
      'name_ar': 'قلائد',
      'icon_name': 'necklace',
    });
    await db.insert('categories', {
      'name_ar': 'أقراط',
      'icon_name': 'earrings',
    });

    // إدراج مواد خام افتراضية
    await db.insert('materials', {'name_ar': 'ذهب'});
    await db.insert('materials', {'name_ar': 'فضة'});
    await db.insert('materials', {'name_ar': 'بلاتين'});

    // إدراج مستخدم افتراضي (مدير)
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123', // في التطبيق الحقيقي يجب تشفيرها
      'full_name': 'مدير النظام',
      'role': 'admin',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    // إدراج إعدادات افتراضية
    final now = DateTime.now().toIso8601String();
    await db.insert('settings', {
      'key': 'gold_price_per_gram',
      'value': '200.0',
      'updated_at': now,
    });
    await db.insert('settings', {
      'key': 'silver_price_per_gram',
      'value': '5.0',
      'updated_at': now,
    });
    await db.insert('settings', {
      'key': 'store_name',
      'value': 'مجوهرات جوهر',
      'updated_at': now,
    });
    await db.insert('settings', {
      'key': 'currency',
      'value': 'د.ل',
      'updated_at': now,
    });
    await db.insert('settings', {
      'key': 'tax_rate',
      'value': '0.0',
      'updated_at': now,
    });
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }
}
