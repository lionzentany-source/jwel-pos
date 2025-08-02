import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class AdvancedBackupService {
  static final AdvancedBackupService _instance =
      AdvancedBackupService._internal();
  factory AdvancedBackupService() => _instance;
  AdvancedBackupService._internal();

  final DatabaseService _databaseService = DatabaseService();

  // إنشاء نسخة احتياطية كاملة
  Future<String> createFullBackup() async {
    try {
      final db = await _databaseService.database;
      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final backupData = <String, dynamic>{};

      // جلب جميع الجداول
      final tables = [
        'categories',
        'materials',
        'items',
        'customers',
        'users',
        'invoices',
        'invoice_items',
        'settings',
      ];

      for (final table in tables) {
        final data = await db.query(table);
        backupData[table] = data;
      }

      // معلومات النسخة الاحتياطية
      backupData['backup_info'] = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
        'total_records': backupData.values.fold(
          0,
          (sum, table) => sum + (table as List).length,
        ),
      };

      // حفظ النسخة الاحتياطية
      final backupDir = await _getBackupDirectory();
      final backupFile = File('${backupDir.path}/backup_$timestamp.json');
      await backupFile.writeAsString(json.encode(backupData));

      debugPrint('تم إنشاء نسخة احتياطية: ${backupFile.path}');
      return backupFile.path;
    } catch (e) {
      debugPrint('خطأ في إنشاء النسخة الاحتياطية: $e');
      rethrow;
    }
  }

  // استعادة البيانات من نسخة احتياطية
  Future<void> restoreFromBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('ملف النسخة الاحتياطية غير موجود');
      }

      final backupContent = await backupFile.readAsString();
      if (backupContent.trim().isEmpty) {
        throw Exception('ملف النسخة الاحتياطية فارغ');
      }
      final backupData = json.decode(backupContent) as Map<String, dynamic>;

      final db = await _databaseService.database;

      // حذف البيانات الحالية
      await _clearAllTables(db);

      // استعادة البيانات
      final tables = [
        'categories',
        'materials',
        'items',
        'customers',
        'users',
        'invoices',
        'invoice_items',
        'settings',
      ];

      for (final table in tables) {
        if (backupData.containsKey(table)) {
          final tableData = backupData[table] as List;
          for (final record in tableData) {
            await db.insert(table, record as Map<String, dynamic>);
          }
        }
      }

      debugPrint('تم استعادة البيانات بنجاح من: $backupPath');
    } catch (e) {
      debugPrint('خطأ في استعادة البيانات: $e');
      rethrow;
    }
  }

  // جدولة النسخ الاحتياطي التلقائي
  Future<void> scheduleAutoBackup({
    bool daily = true,
    bool weekly = false,
  }) async {
    final prefs = await _getBackupPreferences();
    prefs['auto_backup_daily'] = daily;
    prefs['auto_backup_weekly'] = weekly;
    prefs['last_backup'] = DateTime.now().toIso8601String();

    await _saveBackupPreferences(prefs);
    debugPrint(
      'تم تفعيل النسخ الاحتياطي التلقائي - يومي: $daily، أسبوعي: $weekly',
    );
  }

  // فحص الحاجة للنسخ الاحتياطي التلقائي
  Future<bool> shouldCreateAutoBackup() async {
    final prefs = await _getBackupPreferences();
    final lastBackupStr = prefs['last_backup'] as String?;

    if (lastBackupStr == null) return true;

    final lastBackup = DateTime.parse(lastBackupStr);
    final now = DateTime.now();
    final daysSinceLastBackup = now.difference(lastBackup).inDays;

    final dailyEnabled = prefs['auto_backup_daily'] as bool? ?? false;
    final weeklyEnabled = prefs['auto_backup_weekly'] as bool? ?? false;

    if (dailyEnabled && daysSinceLastBackup >= 1) return true;
    if (weeklyEnabled && daysSinceLastBackup >= 7) return true;

    return false;
  }

  // الحصول على قائمة النسخ الاحتياطية
  Future<List<BackupInfo>> getBackupList() async {
    try {
      final backupDir = await _getBackupDirectory();
      final backups = <BackupInfo>[];

      if (await backupDir.exists()) {
        final files = backupDir
            .listSync()
            .where((file) => file.path.endsWith('.json'))
            .cast<File>()
            .toList();

        for (final file in files) {
          try {
            final content = await file.readAsString();
            final data = json.decode(content) as Map<String, dynamic>;
            final info = data['backup_info'] as Map<String, dynamic>?;

            backups.add(
              BackupInfo(
                path: file.path,
                fileName: file.path.split('/').last,
                createdAt: DateTime.parse(
                  info?['created_at'] ?? DateTime.now().toIso8601String(),
                ),
                size: await file.length(),
                totalRecords: info?['total_records'] ?? 0,
              ),
            );
          } catch (e) {
            debugPrint('خطأ في قراءة ملف النسخة الاحتياطية: ${file.path}');
          }
        }
      }

      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return backups;
    } catch (e) {
      debugPrint('خطأ في جلب قائمة النسخ الاحتياطية: $e');
      return [];
    }
  }

  // حذف نسخة احتياطية
  Future<void> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('تم حذف النسخة الاحتياطية: $backupPath');
      }
    } catch (e) {
      debugPrint('خطأ في حذف النسخة الاحتياطية: $e');
      rethrow;
    }
  }

  // تنظيف النسخ الاحتياطية القديمة
  Future<void> cleanupOldBackups({int keepCount = 10}) async {
    try {
      final backups = await getBackupList();
      if (backups.length > keepCount) {
        final toDelete = backups.skip(keepCount);
        for (final backup in toDelete) {
          await deleteBackup(backup.path);
        }
        debugPrint('تم حذف ${toDelete.length} نسخة احتياطية قديمة');
      }
    } catch (e) {
      debugPrint('خطأ في تنظيف النسخ الاحتياطية: $e');
    }
  }

  // مساعدات خاصة
  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<void> _clearAllTables(Database db) async {
    final tables = [
      'invoice_items',
      'invoices',
      'items',
      'customers',
      'users',
      'settings',
      'materials',
      'categories',
    ];
    for (final table in tables) {
      await db.delete(table);
    }
  }

  Future<Map<String, dynamic>> _getBackupPreferences() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final prefsFile = File('${appDir.path}/backup_prefs.json');
      if (await prefsFile.exists()) {
        final content = await prefsFile.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('خطأ في قراءة إعدادات النسخ الاحتياطي: $e');
    }
    return {};
  }

  Future<void> _saveBackupPreferences(Map<String, dynamic> prefs) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final prefsFile = File('${appDir.path}/backup_prefs.json');
      await prefsFile.writeAsString(json.encode(prefs));
    } catch (e) {
      debugPrint('خطأ في حفظ إعدادات النسخ الاحتياطي: $e');
    }
  }
}

class BackupInfo {
  final String path;
  final String fileName;
  final DateTime createdAt;
  final int size;
  final int totalRecords;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.createdAt,
    required this.size,
    required this.totalRecords,
  });

  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get formattedDate {
    return DateFormat('yyyy/MM/dd HH:mm').format(createdAt);
  }
}
