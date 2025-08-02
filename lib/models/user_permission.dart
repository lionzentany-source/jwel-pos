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

class UserRole {
  final String name;
  final String displayName;
  final List<Permission> permissions;
  final int priority; // أعلى رقم = صلاحيات أكثر

  const UserRole({
    required this.name,
    required this.displayName,
    required this.permissions,
    required this.priority,
  });

  static const admin = UserRole(
    name: 'admin',
    displayName: 'مدير النظام',
    priority: 100,
    permissions: Permission.values, // جميع الصلاحيات
  );

  static const manager = UserRole(
    name: 'manager',
    displayName: 'مدير عام',
    priority: 80,
    permissions: [
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
    ],
  );

  static const supervisor = UserRole(
    name: 'supervisor',
    displayName: 'مشرف مبيعات',
    priority: 60,
    permissions: [
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
    ],
  );

  static const cashier = UserRole(
    name: 'cashier',
    displayName: 'بائع',
    priority: 40,
    permissions: [
      Permission.viewInventory,
      Permission.viewPOS,
      Permission.makeSales,
      Permission.viewCustomers,
      Permission.addCustomers,
    ],
  );

  static const viewer = UserRole(
    name: 'viewer',
    displayName: 'مستخدم عرض فقط',
    priority: 20,
    permissions: [
      Permission.viewInventory,
      Permission.viewPOS,
      Permission.viewCustomers,
      Permission.viewReports,
    ],
  );

  static const List<UserRole> allRoles = [
    admin,
    manager,
    supervisor,
    cashier,
    viewer,
  ];

  static UserRole fromName(String name) {
    return allRoles.firstWhere(
      (role) => role.name == name,
      orElse: () => viewer,
    );
  }

  bool hasPermission(Permission permission) {
    return permissions.contains(permission);
  }

  bool canManageUser(UserRole otherRole) {
    return priority > otherRole.priority;
  }
}
