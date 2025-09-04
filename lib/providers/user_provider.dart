import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_service.dart';
import '../models/user.dart';

// Provides the UserService instance.
final userServiceProvider = Provider<UserService>((ref) {
  // This assumes UserService is a singleton and is initialized elsewhere.
  return UserService();
});

// Provides the list of all users for the selection screen.
final allUsersProvider = FutureProvider<List<User>>((ref) async {
  final userService = ref.read(userServiceProvider);
  return await userService.getAllUsers();
});

// Manages the state of the currently authenticated user.
final userNotifierProvider =
    StateNotifierProvider<UserNotifier, AsyncValue<User?>>((ref) {
      final userService = ref.read(userServiceProvider);
      return UserNotifier(userService);
    });

class UserNotifier extends StateNotifier<AsyncValue<User?>> {
  UserNotifier(this._userService) : super(const AsyncValue.data(null));

  final UserService _userService;

  /// Authenticates a user and updates the state.
  Future<bool> authenticate(String username, String password) async {
    state = const AsyncValue.loading();
    debugPrint("--- UserNotifier: Authenticating '$username' ---");
    try {
      final user = await _userService.authenticate(username, password);
      if (user != null) {
        debugPrint(
          "--- UserNotifier: Authentication successful for '$username' ---",
        );
        state = AsyncValue.data(user);
        return true;
      } else {
        debugPrint(
          "--- UserNotifier: Authentication failed for '$username' ---",
        );
        state = const AsyncValue.data(
          null,
        ); // Reset to initial state on failure
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// Logs out the current user.
  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _userService.logout();
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Gets the currently logged-in user.
  User? get currentUser => _userService.currentUser;

  /// Checks if the current user has a specific permission.
  bool hasPermission(String permission) {
    return _userService.hasPermission(permission);
  }

  /// Creates the first admin user (no permission check).
  Future<void> createAdminUser({
    required String username,
    required String password,
    required String fullName,
  }) async {
    try {
      // bypass permission check for first user
      await _userService.createUser(
        username: username,
        password: password,
        fullName: fullName,
        role: UserRole.admin,
      );
    } catch (e) {
      debugPrint('Error creating admin user: $e');
      rethrow;
    }
  }
}
