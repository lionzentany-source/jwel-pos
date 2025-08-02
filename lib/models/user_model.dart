enum UserRole { admin, cashier }

class User {
  final int id;
  final String name;
  final String passwordHash; // لا تقم بتخزين كلمة المرور كنص عادي
  final UserRole role;
  final String? avatar; // مسار للأيقونة أو الصورة الرمزية

  User({
    required this.id,
    required this.name,
    required this.passwordHash,
    required this.role,
    this.avatar,
  });
}
