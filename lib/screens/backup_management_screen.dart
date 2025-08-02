import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../services/advanced_backup_service.dart';

class BackupManagementScreen extends ConsumerStatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  ConsumerState<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends ConsumerState<BackupManagementScreen> {
  final AdvancedBackupService _backupService = AdvancedBackupService();
  List<BackupInfo> _backups = [];
  bool _isLoading = false;
  bool _autoBackupDaily = false;
  bool _autoBackupWeekly = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadSettings();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final backups = await _backupService.getBackupList();
      setState(() => _backups = backups);
    } catch (e) {
      _showError('خطأ في تحميل النسخ الاحتياطية: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSettings() async {
    // تحميل إعدادات النسخ الاحتياطي التلقائي
    setState(() {
      _autoBackupDaily = true; // سيتم تحميلها من الإعدادات
      _autoBackupWeekly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'إدارة النسخ الاحتياطي',
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildAutoBackupSettings(),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                  _buildBackupsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildAutoBackupSettings() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'النسخ الاحتياطي التلقائي',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('نسخ احتياطي يومي'),
              CupertinoSwitch(
                value: _autoBackupDaily,
                onChanged: (value) {
                  setState(() => _autoBackupDaily = value);
                  _backupService.scheduleAutoBackup(daily: value, weekly: _autoBackupWeekly);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('نسخ احتياطي أسبوعي'),
              CupertinoSwitch(
                value: _autoBackupWeekly,
                onChanged: (value) {
                  setState(() => _autoBackupWeekly = value);
                  _backupService.scheduleAutoBackup(daily: _autoBackupDaily, weekly: value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton.filled(
              onPressed: _createBackup,
              child: const Text('إنشاء نسخة احتياطية'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              color: CupertinoColors.systemGrey,
              onPressed: _cleanupOldBackups,
              child: const Text('تنظيف النسخ القديمة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'النسخ الاحتياطية المتاحة (${_backups.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_backups.isEmpty)
            const Center(
              child: Text(
                'لا توجد نسخ احتياطية',
                style: TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            )
          else
            ..._backups.map((backup) => _buildBackupItem(backup)),
        ],
      ),
    );
  }

  Widget _buildBackupItem(BackupInfo backup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.archivebox, color: CupertinoColors.activeBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${backup.formattedDate} • ${backup.formattedSize} • ${backup.totalRecords} سجل',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showBackupOptions(backup),
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showBackupOptions(BackupInfo backup) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(backup.fileName),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('استعادة البيانات'),
            onPressed: () {
              Navigator.pop(context);
              _confirmRestore(backup);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('حذف النسخة الاحتياطية'),
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(backup);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('إلغاء'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      await _backupService.createFullBackup();
      _showSuccess('تم إنشاء النسخة الاحتياطية بنجاح');
      await _loadBackups();
    } catch (e) {
      _showError('خطأ في إنشاء النسخة الاحتياطية: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmRestore(BackupInfo backup) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تأكيد الاستعادة'),
        content: Text('هل أنت متأكد من استعادة البيانات من ${backup.fileName}؟\n\nسيتم حذف جميع البيانات الحالية!'),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('استعادة'),
            onPressed: () {
              Navigator.pop(context);
              _restoreBackup(backup);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BackupInfo backup) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ${backup.fileName}؟'),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('حذف'),
            onPressed: () {
              Navigator.pop(context);
              _deleteBackup(backup);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup(BackupInfo backup) async {
    setState(() => _isLoading = true);
    try {
      await _backupService.restoreFromBackup(backup.path);
      _showSuccess('تم استعادة البيانات بنجاح');
    } catch (e) {
      _showError('خطأ في استعادة البيانات: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBackup(BackupInfo backup) async {
    try {
      await _backupService.deleteBackup(backup.path);
      _showSuccess('تم حذف النسخة الاحتياطية');
      await _loadBackups();
    } catch (e) {
      _showError('خطأ في حذف النسخة الاحتياطية: $e');
    }
  }

  Future<void> _cleanupOldBackups() async {
    try {
      await _backupService.cleanupOldBackups(keepCount: 5);
      _showSuccess('تم تنظيف النسخ الاحتياطية القديمة');
      await _loadBackups();
    } catch (e) {
      _showError('خطأ في تنظيف النسخ الاحتياطية: $e');
    }
  }

  void _showSuccess(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تم بنجاح'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
