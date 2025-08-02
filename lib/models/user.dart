enum UserRole {
  admin('مدير'),
  manager('مدير عام'),
  cashier('بائع'),
  supervisor('مشرف');

  const UserRole(this.displayName);
  final String displayName;
}

class User {
  final int? id;
  final String username;
  final String password; // في التطبيق الحقيقي يجب تشفيرها
  final String fullName;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final String? avatarIcon;
  final String? avatarColor;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    this.isActive = true,
    DateTime? createdAt,
    this.avatarIcon,
    this.avatarColor,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'role': role.name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'avatar_icon': avatarIcon,
      'avatar_color': avatarColor,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id']?.toInt(),
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      fullName: map['full_name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.cashier,
      ),
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      avatarIcon: map['avatar_icon'],
      avatarColor: map['avatar_color'],
    );
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
    String? avatarIcon,
    String? avatarColor,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, fullName: $fullName, role: $role)';
  }
}
