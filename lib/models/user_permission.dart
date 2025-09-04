import 'user.dart';

enum Permission {
  // إدارة المخزون
  viewInventory('عرض المخزون'),
  addItems('إضافة أصناف'),
  editItems('تعديل أصناف'),
  deleteItems('حذف أصناف'),

  // نقطة البيع
  viewPOS('عرض نقطة البيع'),
  makeSales('إجراء مبيعات'),
  applyDiscounts('تطبيق خصومات'),
  refundSales('استرداد مبيعات'),

  // إدارة العملاء
  viewCustomers('عرض العملاء'),
  addCustomers('إضافة عملاء'),
  editCustomers('تعديل عملاء'),
  deleteCustomers('حذف عملاء'),

  // التقارير
  viewReports('عرض التقارير'),
  exportReports('تصدير التقارير'),
  viewFinancialReports('عرض التقارير المالية'),

  // الإعدادات
  viewSettings('عرض الإعدادات'),
  editSettings('تعديل الإعدادات'),
  manageUsers('إدارة المستخدمين'),
  manageBackups('إدارة النسخ الاحتياطي'),

  // إدارة النظام
  systemAdmin('إدارة النظام'),
  viewLogs('عرض السجلات'),
  manageDatabase('إدارة قاعدة البيانات');

  const Permission(this.displayName);
  final String displayName;
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'مدير النظام';
      case UserRole.manager:
        return 'مدير عام';
      case UserRole.supervisor:
        return 'مشرف مبيعات';
      case UserRole.cashier:
        return 'بائع';
    }
    // جميع الحالات مغطاة ولا حاجة لأي كود إضافي هنا
  }

  int get priority {
    switch (this) {
      case UserRole.admin:
        return 100;
      case UserRole.manager:
        return 80;
      case UserRole.supervisor:
        return 60;
      case UserRole.cashier:
        return 40;
    }
    // جميع الحالات مغطاة ولا حاجة لأي كود إضافي هنا
  }

  List<Permission> get permissions {
    switch (this) {
      case UserRole.admin:
        return Permission.values;
      case UserRole.manager:
        return [
          Permission.viewInventory,
          Permission.addItems,
          Permission.editItems,
          Permission.viewPOS,
          Permission.makeSales,
          Permission.applyDiscounts,
          Permission.refundSales,
          Permission.viewCustomers,
          Permission.addCustomers,
          Permission.editCustomers,
          Permission.viewReports,
          Permission.exportReports,
          Permission.viewFinancialReports,
          Permission.viewSettings,
          Permission.editSettings,
          Permission.viewLogs,
        ];
      case UserRole.supervisor:
        return [
          Permission.viewInventory,
          Permission.addItems,
          Permission.editItems,
          Permission.viewPOS,
          Permission.makeSales,
          Permission.applyDiscounts,
          Permission.viewCustomers,
          Permission.addCustomers,
          Permission.editCustomers,
          Permission.viewReports,
          Permission.viewSettings,
        ];
      case UserRole.cashier:
        return [
          Permission.viewInventory,
          Permission.viewPOS,
          Permission.makeSales,
          Permission.viewCustomers,
          Permission.addCustomers,
        ];
    }
    // جميع الحالات مغطاة ولا حاجة لأي كود إضافي هنا
  }

  bool hasPermission(Permission permission) {
    return permissions.contains(permission);
  }

  bool canManageUser(UserRole otherRole) {
    return priority > otherRole.priority;
  }
}
