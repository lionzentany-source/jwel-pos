import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
// import 'package:sqflite/sqflite.dart'; // غير مستخدم هنا

import '../models/user.dart';
import '../repositories/user_repository.dart';

/// # Advanced User Service Implementation
///
/// This class provides advanced user management functionality including
/// authentication, session management, permissions, and audit logging.
///
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  User? _currentUser;

  User? get currentUser => _currentUser;

  late UserRepository _userRepository;

  // Initialize the service with a UserRepository instance.
  // This allows for dependency injection and testing.
  Future<void> init(UserRepository userRepository) async {
    _userRepository = userRepository;
    // Ensure admin user exists
    await _ensureAdminUserExists();
  }

  final Map<String, List<UserRole>> _userPermissions = {
    'manage_inventory': [UserRole.admin, UserRole.manager],
    'process_sales': [UserRole.admin, UserRole.manager, UserRole.cashier, UserRole.supervisor],
    'view_reports': [UserRole.admin, UserRole.manager, UserRole.supervisor],
    'manage_users': [UserRole.admin],
    'manage_settings': [UserRole.admin, UserRole.manager],
    'view_customers': [UserRole.admin, UserRole.manager, UserRole.cashier, UserRole.supervisor],
    'manage_categories': [UserRole.admin, UserRole.manager],
    'manage_materials': [UserRole.admin, UserRole.manager],
    'backup_restore': [UserRole.admin],
    'printer_settings': [UserRole.admin, UserRole.manager],
    'rfid_management': [UserRole.admin, UserRole.manager, UserRole.supervisor],
  };

  final List<UserActivity> _activityLog = [];
  final int _maxLogEntries = 1000;

  /// Authenticates a user with username and password.
  ///
  /// Returns the [User] object on success, otherwise returns `null`.
  Future<User?> authenticate(String username, String password) async {
    try {
      debugPrint("--- AUTHENTICATING USER ---");
      debugPrint("Username: $username");
      final providedPasswordHash = _hashPassword(password);
      debugPrint("Provided Password Hash: $providedPasswordHash");

      final user = await _userRepository.getUserByUsername(username);
      debugPrint("User from DB: ${user?.toMap()}");
      debugPrint("DB Password Hash: ${user?.password}");


      if (user != null && user.password == providedPasswordHash) {
        _currentUser = user;
        _logActivity('login', 'User logged in successfully');
        debugPrint("Authentication successful for user: $username");
        return _currentUser;
      }

      _logActivity('login_failed', 'Failed login attempt for user: $username');
      debugPrint("Authentication failed for user: $username");
      return null;
    } catch (error) {
      debugPrint("Error during authentication: $error");
      // In a real app, you might want to throw a custom exception
      // or return a result object with an error message.
      return null;
    }
  }

  /// Logs out the current user.
  Future<void> logout() async {
    try {
      debugPrint("--- LOGGING OUT USER ---");
      if (_currentUser != null) {
        _logActivity('logout', 'User logged out');
        _currentUser = null;
      }
    } catch (error) {
      debugPrint("Error during logout: $error");
    }
  }

  /// Checks if the current user has permission to perform an action.
  ///
  /// Returns `true` if the user has permission, otherwise `false`.
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;

    final allowedRoles = _userPermissions[permission];

    if (allowedRoles == null) return true; // No specific role required

    // Admin always has all permissions
    if (_currentUser!.role == UserRole.admin) return true;

    // Check if user's role is in the allowed roles list
    return allowedRoles.contains(_currentUser!.role);
  }

  /// Fetches all users from the repository.
  Future<List<User>> getAllUsers() async {
    try {
      return await _userRepository.getAllUsers();
    } catch (error) {
      debugPrint("Error getting all users: $error");
      return [];
    }
  }

  /// Creates a new user.
  ///
  /// The [username] must be unique and between 3 and 20 characters.
  /// The [password] must be at least 8 characters long.
  ///
  /// Returns the created [User] on success, otherwise throws an exception.
  Future<User> createUser({
    required String username,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    // Check for permission first to avoid unnecessary validation.
    if (!hasPermission('manage_users')) {
      throw Exception("Permission denied: Cannot create user");
    }

    // Data validation
    _validateUsername(username);
    _validatePassword(password);

    try {
      debugPrint("--- CREATING NEW USER ---");
      debugPrint("Username: $username");

      final newUser = User(
        username: username,
        password: _hashPassword(password),
        fullName: fullName,
        role: role,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _userRepository.insertUser(newUser);
      final createdUser = await _userRepository.getUserByUsername(username);

      if (createdUser == null) {
        throw Exception("Failed to create user.");
      }

      _logActivity('user_created', 'Created user: $username');
      debugPrint("User created successfully: $username");
      return createdUser;
    } catch (error) {
      debugPrint("Error creating user: $error");
      throw Exception("An error occurred while creating the user: $error");
    }
  }

  /// Updates user information.
  ///
  /// Returns the updated [User] on success, otherwise throws an exception.
  Future<User> updateUser({
    required int userId,
    String? username,
    String? password,
    String? fullName,
    UserRole? role,
    bool? isActive,
  }) async {
    if (!hasPermission('manage_users')) {
      throw Exception("Permission denied: Cannot update user");
    }

    try {
      debugPrint("--- UPDATING USER ---");
      debugPrint("User ID: $userId");

      final existingUser = await _userRepository.getById(userId);
      if (existingUser == null) {
        throw Exception("User not found: $userId");
      }

      // Data validation
      if (username != null) {
        _validateUsername(username);
      }
      if (password != null) {
        _validatePassword(password);
      }

      final updatedUser = existingUser.copyWith(
        username: username,
        password: password != null ? _hashPassword(password) : null,
        fullName: fullName,
        role: role,
        isActive: isActive,
      );

      await _userRepository.updateUser(updatedUser);

      _logActivity('user_updated', 'Updated user ID: $userId');
      debugPrint("User updated successfully: $userId");
      return updatedUser;
    } catch (error) {
      debugPrint("Error updating user: $error");
      throw Exception("An error occurred while updating the user: $error");
    }
  }

  /// Deletes a user.
  ///
  /// Returns `true` on success, otherwise `false`.
  Future<bool> deleteUser(int userId) async {
    if (!hasPermission('manage_users')) {
      debugPrint("Permission denied: Cannot delete user");
      return false;
    }

    try {
      debugPrint("--- DELETING USER ---");
      debugPrint("User ID: $userId");

      final int rowsAffected = await _userRepository.deleteUser(userId);

      if (rowsAffected > 0) {
        _logActivity('user_deleted', 'Deleted user ID: $userId');
        debugPrint("User deleted successfully: $userId");
        return true;
      } else {
        debugPrint("User not found for deletion: $userId");
        return false;
      }
    } catch (error) {
      debugPrint("Error deleting user: $error");
      return false;
    }
  }

  /// Changes a user's password.
  ///
  /// Returns `true` on success, otherwise `false`.
  Future<bool> changePassword(int userId, String newPassword) async {
    // Users can change their own password, or admins can change any password
    if (_currentUser == null ||
        (_currentUser!.id != userId && !hasPermission('manage_users'))) {
      debugPrint("Permission denied: Cannot change password");
      return false;
    }

    try {
      debugPrint("--- CHANGING USER PASSWORD ---");
      debugPrint("User ID: $userId");

      _validatePassword(newPassword);

      final existingUser = await _userRepository.getById(userId);
      if (existingUser == null) {
        debugPrint("User not found: $userId");
        return false;
      }

      final updatedUser = existingUser.copyWith(
        password: _hashPassword(newPassword),
      );

      await _userRepository.updateUser(updatedUser);

      _logActivity('password_changed', 'Changed password for user ID: $userId');
      debugPrint("Password changed successfully for user: $userId");
      return true;
    } catch (error) {
      debugPrint("Error changing password: $error");
      return false;
    }
  }

  /// Gets the user activity log.
  ///
  /// Requires 'manage_users' permission.
  List<UserActivity> getActivityLog() {
    if (!hasPermission('manage_users')) {
      debugPrint("Permission denied: Cannot access activity log");
      return [];
    }

    return List.unmodifiable(_activityLog);
  }

  /// Hashes a password using SHA-256.
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Logs a user activity.
  void _logActivity(String action, String description) {
    final activity = UserActivity(
      userId: _currentUser?.id,
      username: _currentUser?.username ?? 'anonymous',
      action: action,
      description: description,
      timestamp: DateTime.now(),
    );

    _activityLog.add(activity);

    // Keep only the last _maxLogEntries
    if (_activityLog.length > _maxLogEntries) {
      _activityLog.removeRange(0, _activityLog.length - _maxLogEntries);
    }
  }

  /// Ensures that default users exist in the database.
  Future<void> _ensureAdminUserExists() async {
    final adminUser = await _userRepository.getUserByUsername('admin');
    if (adminUser == null) {
      debugPrint("Creating default users...");
      
      // حساب المدير الرئيسي
      final newAdmin = User(
        username: 'admin',
        password: _hashPassword('admin123'),
        fullName: 'حساب المدير',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
        avatarIcon: 'person_crop_circle_fill',
        avatarColor: 'systemBlue',
      );
      await _userRepository.insertUser(newAdmin);
      debugPrint("Default admin user created.");
    }
  }

  /// Validates the username format.
  void _validateUsername(String username) {
    if (username.length < 3 || username.length > 20) {
      throw Exception("Username must be between 3 and 20 characters.");
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      throw Exception("Username can only contain letters, numbers, and underscores.");
    }
  }

  /// Validates the password format.
  void _validatePassword(String password) {
    if (password.length < 8) {
      throw Exception("Password must be at least 8 characters long.");
    }
    // Add more complex password validation if needed
  }
}

/// Represents a user activity log entry.
class UserActivity {
  final int? userId;
  final String username;
  final String action;
  final String description;
  final DateTime timestamp;

  UserActivity({
    this.userId,
    required this.username,
    required this.action,
    required this.description,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'UserActivity(userId: $userId, username: $username, action: $action, description: $description, timestamp: $timestamp)';
  }
}
