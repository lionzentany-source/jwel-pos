import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_activity.dart';
import '../services/database_service.dart';

class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  final DatabaseService _databaseService = DatabaseService();

  // تسجيل نشاط جديد
  Future<void> logActivity({
    required int userId,
    required String username,
    required ActivityType activityType,
    required String description,
    Map<String, dynamic>? metadata,
    String? ipAddress,
    String? deviceInfo,
  }) async {
    try {
      final activity = UserActivity(
        userId: userId,
        username: username,
        activityType: activityType,
        description: description,
        metadata: metadata,
        ipAddress: ipAddress,
        deviceInfo: deviceInfo,
      );

      final db = await _databaseService.database;
      await db.insert('user_activities', activity.toMap());
      
      debugPrint('تم تسجيل النشاط: ${activityType.displayName} للمستخدم: $username');
    } catch (e) {
      debugPrint('خطأ في تسجيل النشاط: $e');
    }
  }

  // جلب أنشطة مستخدم معين
  Future<List<UserActivity>> getUserActivities({
    required int userId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await _databaseService.database;
      String whereClause = 'user_id = ?';
      List<dynamic> whereArgs = [userId];

      if (startDate != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final result = await db.query(
        'user_activities',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return result.map((map) => UserActivity.fromMap(map)).toList();
    } catch (e) {
      debugPrint('خطأ في جلب أنشطة المستخدم: $e');
      return [];
    }
  }

  // جلب جميع الأنشطة
  Future<List<UserActivity>> getAllActivities({
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
    ActivityType? activityType,
  }) async {
    try {
      final db = await _databaseService.database;
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (startDate != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      if (activityType != null) {
        whereClause += ' AND activity_type = ?';
        whereArgs.add(activityType.name);
      }

      final result = await db.query(
        'user_activities',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return result.map((map) => UserActivity.fromMap(map)).toList();
    } catch (e) {
      debugPrint('خطأ في جلب الأنشطة: $e');
      return [];
    }
  }

  // إحصائيات النشاط
  Future<Map<String, int>> getActivityStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await _databaseService.database;
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (startDate != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final result = await db.query(
        'user_activities',
        columns: ['activity_type', 'COUNT(*) as count'],
        where: whereClause,
        whereArgs: whereArgs,
        groupBy: 'activity_type',
      );

      final stats = <String, int>{};
      for (final row in result) {
        stats[row['activity_type'] as String] = row['count'] as int;
      }

      return stats;
    } catch (e) {
      debugPrint('خطأ في جلب إحصائيات النشاط: $e');
      return {};
    }
  }

  // تنظيف الأنشطة القديمة
  Future<void> cleanupOldActivities({int keepDays = 90}) async {
    try {
      final db = await _databaseService.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
      
      final deletedCount = await db.delete(
        'user_activities',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      debugPrint('تم حذف $deletedCount نشاط قديم');
    } catch (e) {
      debugPrint('خطأ في تنظيف الأنشطة القديمة: $e');
    }
  }

  // إنشاء جدول الأنشطة (يتم استدعاؤه من DatabaseService)
  static Future<void> createActivityTable(Database db) async {
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
  }
}

