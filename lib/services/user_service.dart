import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/user.dart';
import '../repositories/base_repository.dart';

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

  final Map<String, UserRole> _userPermissions = {
    'manage_inventory': UserRole.admin,
    'process_sales': UserRole.cashier,
    'view_reports': UserRole.admin,
    'manage_users': UserRole.admin,
    'manage_settings': UserRole.admin,
    'view_customers': UserRole.cashier,
  };

  final List<UserActivity> _activityLog = [];
  final int _maxLogEntries = 1000;

  /// Authenticates a user with username and password
  Future<User?> authenticate(String username, String password) async {
    try {
      debugPrint("--- AUTHENTICATING USER ---");
      debugPrint("Username: $username");

      // In a real implementation, you would:
      // 1. Query the database for the user
      // 2. Hash the provided password
      // 3. Compare with stored hash
      // 4. Return user if authentication is successful

      // For demonstration, we'll simulate successful authentication
      // for the default admin user
      if (username == 'admin' && password == 'admin123') {
        _currentUser = User(
          id: 1,
          username: 'admin',
          password: _hashPassword(password),
          fullName: 'مدير النظام',
          role: UserRole.admin,
          isActive: true,
          createdAt: DateTime.now(),
        );

        _logActivity('login', 'User logged in successfully');
        debugPrint("Authentication successful for user: $username");
        return _currentUser;
      }

      _logActivity('login_failed', 'Failed login attempt for user: $username');
      debugPrint("Authentication failed for user: $username");
      return null;
    } catch (e) {
      debugPrint("Error during authentication: $e");
      return null;
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    try {
      debugPrint("--- LOGGING OUT USER ---");
      if (_currentUser != null) {
        _logActivity('logout', 'User logged out');
        _currentUser = null;
      }
    } catch (e) {
      debugPrint("Error during logout: $e");
    }
  }

  /// Checks if current user has permission to perform an action
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;

    final requiredRole = _userPermissions[permission];
    if (requiredRole == null) return true; // No specific role required

    // Admin has all permissions
    if (_currentUser!.role == UserRole.admin) return true;

    // Check if user's role matches required role
    return _currentUser!.role == requiredRole;
  }

  /// Creates a new user (admin only)
  Future<User?> createUser({
    required String username,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    if (!hasPermission('manage_users')) {
      debugPrint("Permission denied: Cannot create user");
      return null;
    }

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

      _logActivity('user_created', 'Created user: $username');
      debugPrint("User created successfully: $username");
      return newUser;
    } catch (e) {
      debugPrint("Error creating user: $e");
      return null;
    }
  }

  /// Updates user information
  Future<User?> updateUser({
    required int userId,
    String? username,
    String? password,
    String? fullName,
    UserRole? role,
    bool? isActive,
  }) async {
    if (!hasPermission('manage_users')) {
      debugPrint("Permission denied: Cannot update user");
      return null;
    }

    try {
      debugPrint("--- UPDATING USER ---");
      debugPrint("User ID: $userId");

      // In a real implementation, you would:
      // 1. Query the database for the user
      // 2. Update the fields
      // 3. Save to database

      _logActivity('user_updated', 'Updated user ID: $userId');
      debugPrint("User updated successfully: $userId");
      return null; // Return updated user in real implementation
    } catch (e) {
      debugPrint("Error updating user: $e");
      return null;
    }
  }

  /// Deletes a user (admin only)
  Future<bool> deleteUser(int userId) async {
    if (!hasPermission('manage_users')) {
      debugPrint("Permission denied: Cannot delete user");
      return false;
    }

    try {
      debugPrint("--- DELETING USER ---");
      debugPrint("User ID: $userId");

      // In a real implementation, you would:
      // 1. Query the database for the user
      // 2. Delete from database

      _logActivity('user_deleted', 'Deleted user ID: $userId');
      debugPrint("User deleted successfully: $userId");
      return true;
    } catch (e) {
      debugPrint("Error deleting user: $e");
      return false;
    }
  }

  /// Changes user password
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

      // In a real implementation, you would:
      // 1. Query the database for the user
      // 2. Hash the new password
      // 3. Update password in database

      _logActivity('password_changed', 'Changed password for user ID: $userId');
      debugPrint("Password changed successfully for user: $userId");
      return true;
    } catch (e) {
      debugPrint("Error changing password: $e");
      return false;
    }
  }

  /// Gets user activity log
  List<UserActivity> getActivityLog() {
    if (!hasPermission('manage_users')) {
      debugPrint("Permission denied: Cannot access activity log");
      return [];
    }

    return List.unmodifiable(_activityLog);
  }

  /// Hashes a password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Logs user activity
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
}

/// Represents a user activity log entry
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
