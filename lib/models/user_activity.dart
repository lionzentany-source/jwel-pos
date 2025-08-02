import 'dart:convert';
import 'package:intl/intl.dart';

enum ActivityType {
  login('تسجيل دخول'),
  logout('تسجيل خروج'),
  sale('عملية بيع'),
  refund('استرداد'),
  addItem('إضافة صنف'),
  editItem('تعديل صنف'),
  deleteItem('حذف صنف'),
  addCustomer('إضافة عميل'),
  editCustomer('تعديل عميل'),
  deleteCustomer('حذف عميل'),
  viewReport('عرض تقرير'),
  exportReport('تصدير تقرير'),
  printInvoice('طباعة فاتورة'),
  printReport('طباعة تقرير'),
  backup('نسخ احتياطي'),
  restore('استعادة بيانات'),
  settingsChange('تغيير إعدادات'),
  userManagement('إدارة مستخدمين'),
  systemAccess('وصول للنظام');

  const ActivityType(this.displayName);
  final String displayName;
}

class UserActivity {
  final int? id;
  final int userId;
  final String username;
  final ActivityType activityType;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final String? ipAddress;
  final String? deviceInfo;

  UserActivity({
    this.id,
    required this.userId,
    required this.username,
    required this.activityType,
    required this.description,
    this.metadata,
    DateTime? timestamp,
    this.ipAddress,
    this.deviceInfo,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'activity_type': activityType.name,
      'description': description,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'timestamp': timestamp.toIso8601String(),
      'ip_address': ipAddress,
      'device_info': deviceInfo,
    };
  }

  factory UserActivity.fromMap(Map<String, dynamic> map) {
    return UserActivity(
      id: map['id']?.toInt(),
      userId: map['user_id']?.toInt() ?? 0,
      username: map['username'] ?? '',
      activityType: ActivityType.values.firstWhere(
        (e) => e.name == map['activity_type'],
        orElse: () => ActivityType.systemAccess,
      ),
      description: map['description'] ?? '',
      metadata: map['metadata'] != null
          ? jsonDecode(map['metadata']) as Map<String, dynamic>
          : null,
      timestamp: DateTime.parse(map['timestamp']),
      ipAddress: map['ip_address'],
      deviceInfo: map['device_info'],
    );
  }

  String get formattedTimestamp {
    return DateFormat('yyyy/MM/dd HH:mm:ss').format(timestamp);
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    if (difference.inDays < 7) return 'منذ ${difference.inDays} يوم';
    return formattedTimestamp;
  }
}
