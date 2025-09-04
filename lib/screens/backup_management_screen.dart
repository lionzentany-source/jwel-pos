import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_brand_theme.dart';
import '../widgets/adaptive_scaffold.dart';
import '../services/advanced_backup_service.dart';

class BackupManagementScreen extends ConsumerStatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  ConsumerState<BackupManagementScreen> createState() =>
      _BackupManagementScreenState();
}

class _BackupManagementScreenState
    extends ConsumerState<BackupManagementScreen> {
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
    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'إدارة النسخ الاحتياطي',
        body: _isLoading
            ? const Center(child: ProgressRing())
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
      ),
    );
  }

  Widget _buildAutoBackupSettings() {
    return Card(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      backgroundColor: Color(0xffffffff),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'النسخ الاحتياطي التلقائي',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xff222b45),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نسخ احتياطي يومي',
                style: TextStyle(color: Color(0xff222b45)),
              ),
              ToggleSwitch(
                checked: _autoBackupDaily,
                onChanged: (value) {
                  setState(() => _autoBackupDaily = value);
                  _backupService.scheduleAutoBackup(
                    daily: value,
                    weekly: _autoBackupWeekly,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نسخ احتياطي أسبوعي',
                style: TextStyle(color: Color(0xff222b45)),
              ),
              ToggleSwitch(
                checked: _autoBackupWeekly,
                onChanged: (value) {
                  setState(() => _autoBackupWeekly = value);
                  _backupService.scheduleAutoBackup(
                    daily: _autoBackupDaily,
                    weekly: value,
                  );
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
            child: Builder(
              builder: (context) {
                final t = AppBrandTheme.of(context);
                return SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _createBackup,
                    style: t.primaryFilledButtonStyle(),
                    child: const Text('إنشاء نسخة احتياطية'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder: (context) {
                final t = AppBrandTheme.of(context);
                return SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _cleanupOldBackups,
                    style: t.primaryFilledButtonStyle(),
                    child: const Text('تنظيف النسخ القديمة'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupsList() {
    return Card(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      backgroundColor: Color(0xffffffff),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'النسخ الاحتياطية المتاحة (${_backups.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xff222b45),
            ),
          ),
          const SizedBox(height: 16),
          if (_backups.isEmpty)
            Center(
              child: Text(
                'لا توجد نسخ احتياطية',
                style: TextStyle(color: Color(0xff222b45)),
              ),
            )
          else
            ..._backups.map((backup) => _buildBackupItem(backup)),
        ],
      ),
    );
  }

  Widget _buildBackupItem(BackupInfo backup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      backgroundColor: Color(0xffffffff),
      child: Row(
        children: [
          Icon(FluentIcons.archive, color: Color(0xff0078d4)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup.fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xff222b45),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${backup.formattedDate} • ${backup.formattedSize} • ${backup.totalRecords} سجل',
                  style: TextStyle(color: Color(0xff222b45)),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final t = AppBrandTheme.of(context);
              return SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: () => _showBackupOptions(backup),
                  style: t.primaryFilledButtonStyle(),
                  child: const Icon(FluentIcons.more, color: Color(0xffffffff)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showBackupOptions(BackupInfo backup) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(backup.fileName),
        content: const Text('اختر إجراءً:'),
        actions: [
          Button(
            child: const Text('استعادة البيانات'),
            onPressed: () {
              Navigator.pop(context);
              _confirmRestore(backup);
            },
          ),
          FilledButton(
            child: const Text('حذف النسخة الاحتياطية'),
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(backup);
            },
          ),
          Button(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
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
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('تأكيد الاستعادة'),
        content: Text(
          'هل أنت متأكد من استعادة البيانات من ${backup.fileName}؟\n\nسيتم حذف جميع البيانات الحالية!',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreBackup(backup);
            },
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BackupInfo backup) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ${backup.fileName}؟'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBackup(backup);
            },
            child: const Text('حذف'),
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
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('نجاح'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }
}
