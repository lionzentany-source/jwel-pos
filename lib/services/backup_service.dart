import 'package:flutter/foundation.dart';
import 'advanced_backup_service.dart';

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  Future<void> performBackup() async {
    try {
      debugPrint("--- PERFORMING AUTOMATIC BACKUP ---");
      final backupPath = await AdvancedBackupService().createFullBackup();
      debugPrint("Backup created at: $backupPath");
    } catch (e) {
      debugPrint("Error during backup: $e");
      rethrow;
    }
  }
}
