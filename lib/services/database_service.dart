import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseService {
  Database? _database;
  static DatabaseService? _instance;
  static DatabaseService? _testInstance;

  // Private constructor
  DatabaseService._internal();

  // Factory constructor to return the singleton instance
  factory DatabaseService() {
    if (_testInstance != null) {
      return _testInstance!;
    }
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  // Setter for test instance
  static set testInstance(DatabaseService? instance) {
    _testInstance = instance;
  }

  // Reset for testing
  static void resetForTesting() {
    _instance = null;
    _testInstance = null;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'jwe_pos.db');

      return await openDatabase(
        path,
    version: 7,
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

    // جدول المواد الخام (أضيفت أعمدة is_variable و price_per_gram في الإصدار 6)
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_ar TEXT NOT NULL,
        is_variable INTEGER NOT NULL DEFAULT 0,
        price_per_gram REAL NOT NULL DEFAULT 0
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
        cost_price REAL NOT NULL DEFAULT 0,
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
        created_at TEXT NOT NULL,
        avatar_icon TEXT,
        avatar_color TEXT
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

    // جدول أنشطة المستخدمين
    await db.execute('''
      CREATE TABLE user_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        username TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        description TEXT NOT NULL,
        metadata TEXT,
        timestamp TEXT NOT NULL,
        ip_address TEXT,
        device_info TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // إنشاء فهارس للبحث السريع
    await db.execute('CREATE INDEX idx_user_activities_user_id ON user_activities(user_id)');
    await db.execute('CREATE INDEX idx_user_activities_timestamp ON user_activities(timestamp)');
    await db.execute('CREATE INDEX idx_user_activities_type ON user_activities(activity_type)');

    // جدول المصروفات
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // إدراج البيانات الأولية
    await _insertInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // إضافة حقول الأيقونة واللون للمستخدمين
      await db.execute('ALTER TABLE users ADD COLUMN avatar_icon TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN avatar_color TEXT');
      
      // تحديث المستخدمين الموجودين بأيقونات افتراضية
      await db.update('users', {
        'avatar_icon': 'person_crop_circle_fill',
        'avatar_color': 'systemBlue',
      }, where: 'username = ?', whereArgs: ['admin']);
    }
    
    if (oldVersion < 3) {
      // إضافة جدول أنشطة المستخدمين إذا لم يكن موجوداً
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_activities (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          username TEXT NOT NULL,
          activity_type TEXT NOT NULL,
          description TEXT NOT NULL,
          metadata TEXT,
          timestamp TEXT NOT NULL,
          ip_address TEXT,
          device_info TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
      
      // إنشاء فهارس للبحث السريع
      await db.execute('CREATE INDEX IF NOT EXISTS idx_user_activities_user_id ON user_activities(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_user_activities_timestamp ON user_activities(timestamp)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_user_activities_type ON user_activities(activity_type)');
    }
    
    if (oldVersion < 4) {
      // إضافة عمود سعر التكلفة للأصناف
      await db.execute('ALTER TABLE items ADD COLUMN cost_price REAL NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 6) {
      // إضافة أعمدة التسعير المتغير للمواد
      final columns = await db.rawQuery('PRAGMA table_info(materials)');
      final hasIsVariable = columns.any((c) => c['name'] == 'is_variable');
      final hasPricePerGram = columns.any((c) => c['name'] == 'price_per_gram');
      if (!hasIsVariable) {
        await db.execute('ALTER TABLE materials ADD COLUMN is_variable INTEGER NOT NULL DEFAULT 0');
      }
      if (!hasPricePerGram) {
        await db.execute('ALTER TABLE materials ADD COLUMN price_per_gram REAL NOT NULL DEFAULT 0');
      }

      // ترقية المواد الافتراضية (ذهب وفضة) إلى مواد متغيرة باستخدام القيم المخزنة في الإعدادات
      final goldSetting = await db.query('settings', where: 'key = ?', whereArgs: ['gold_price_per_gram'], limit: 1);
      final silverSetting = await db.query('settings', where: 'key = ?', whereArgs: ['silver_price_per_gram'], limit: 1);
      final goldPrice = goldSetting.isNotEmpty ? double.tryParse(goldSetting.first['value'] as String) ?? 0 : 0;
      final silverPrice = silverSetting.isNotEmpty ? double.tryParse(silverSetting.first['value'] as String) ?? 0 : 0;
      // تحديث السجلات حسب الاسم العربي
      await db.update('materials', {'is_variable': 1, 'price_per_gram': goldPrice}, where: 'name_ar = ?', whereArgs: ['ذهب']);
      await db.update('materials', {'is_variable': 1, 'price_per_gram': silverPrice}, where: 'name_ar = ?', whereArgs: ['فضة']);
    }
      if (oldVersion < 7) {
        // حذف المفاتيح القديمة لأسعار الذهب والفضة بعد الانتقال للتسعير الديناميكي
        await db.delete('settings', where: 'key IN (?, ?)', whereArgs: ['gold_price_per_gram', 'silver_price_per_gram']);
      }
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

  // إدراج مواد خام افتراضية (ذهب وفضة كمواد متغيرة السعر)
  await db.insert('materials', {'name_ar': 'ذهب', 'is_variable': 1, 'price_per_gram': 200.0});
  await db.insert('materials', {'name_ar': 'فضة', 'is_variable': 1, 'price_per_gram': 5.0});
  await db.insert('materials', {'name_ar': 'بلاتين', 'is_variable': 0, 'price_per_gram': 0});

    // إدراج المستخدمين الافتراضيين
    final now = DateTime.now().toIso8601String();
    
    // حساب المدير الرئيسي
    final adminPassword = sha256.convert(utf8.encode('admin123')).toString();
    await db.insert('users', {
      'username': 'admin',
      'password': adminPassword,
      'full_name': 'حساب المدير',
      'role': 'admin',
      'is_active': 1,
      'created_at': now,
      'avatar_icon': 'person_crop_circle_fill',
      'avatar_color': 'systemBlue',
    });
    
    // مدير عام
    final managerPassword = sha256.convert(utf8.encode('manager123')).toString();
    await db.insert('users', {
      'username': 'manager',
      'password': managerPassword,
      'full_name': 'المدير العام',
      'role': 'manager',
      'is_active': 1,
      'created_at': now,
      'avatar_icon': 'person_badge_plus',
      'avatar_color': 'systemGreen',
    });
    
    // بائع رئيسي
    final cashierPassword = sha256.convert(utf8.encode('cashier123')).toString();
    await db.insert('users', {
      'username': 'cashier',
      'password': cashierPassword,
      'full_name': 'البائع الرئيسي',
      'role': 'cashier',
      'is_active': 1,
      'created_at': now,
      'avatar_icon': 'person_circle',
      'avatar_color': 'systemOrange',
    });
    
    // مشرف المبيعات
    final supervisorPassword = sha256.convert(utf8.encode('supervisor123')).toString();
    await db.insert('users', {
      'username': 'supervisor',
      'password': supervisorPassword,
      'full_name': 'مشرف المبيعات',
      'role': 'supervisor',
      'is_active': 1,
      'created_at': now,
      'avatar_icon': 'person_2',
      'avatar_color': 'systemPurple',
    });

    // إدراج إعدادات افتراضية
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
        'value': 'د.ل دينار ليبي',
        'updated_at': now,
      });
      await db.insert('settings', {
        'key': 'tax_rate',
        'value': '0.0',
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
