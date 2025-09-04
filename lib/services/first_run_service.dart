import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import 'user_service.dart';

/// Handles first-run logic like forcing admin password setup on initial login.
class FirstRunService {
  FirstRunService({
    SettingsRepository? settingsRepository,
    UserRepository? userRepository,
  }) : _settingsRepository = settingsRepository ?? SettingsRepository(),
       _userRepository = userRepository ?? UserRepository();

  final SettingsRepository _settingsRepository;
  final UserRepository _userRepository;

  /// Returns true if the system still requires the admin to set a new password.
  Future<bool> isAdminPasswordSetupRequired() async {
    return await _settingsRepository.getBoolFlag(
      SettingsRepository.kRequireAdminPasswordSetup,
      defaultValue: false,
    );
  }

  /// Marks the one-time admin password setup as completed.
  Future<void> markAdminPasswordSetupDone() async {
    await _settingsRepository.setBoolFlag(
      SettingsRepository.kRequireAdminPasswordSetup,
      false,
    );
  }

  /// Change the admin user's password securely and mark the flag as done.
  /// Returns true on success.
  Future<bool> completeAdminPasswordSetup(String newPassword) async {
    // Find admin user
    final admin = await _userRepository.getUserByUsername('admin');
    if (admin == null) return false;
    // Change password using UserService to reuse hashing/validation
    final userService = UserService();
    final success = await userService.changePassword(admin.id!, newPassword);
    if (success) {
      await markAdminPasswordSetupDone();
    }
    return success;
  }
}
