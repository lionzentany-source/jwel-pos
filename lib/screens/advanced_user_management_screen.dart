import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../models/user.dart';
import '../models/user_permission.dart' as perm;
import '../models/user_activity.dart';
import '../services/user_activity_service.dart';
import '../providers/user_provider.dart';

class AdvancedUserManagementScreen extends ConsumerStatefulWidget {
  const AdvancedUserManagementScreen({super.key});

  @override
  ConsumerState<AdvancedUserManagementScreen> createState() => _AdvancedUserManagementScreenState();
}

class _AdvancedUserManagementScreenState extends ConsumerState<AdvancedUserManagementScreen> {
  final UserActivityService _activityService = UserActivityService();
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'إدارة المستخدمين المتقدمة',
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildUsersTab()
                : _selectedTabIndex == 1
                    ? _buildPermissionsTab()
                    : _buildActivityTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: _selectedTabIndex,
        onValueChanged: (value) => setState(() => _selectedTabIndex = value!),
        children: const {
          0: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('المستخدمين'),
          ),
          1: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('الصلاحيات'),
          ),
          2: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('النشاط'),
          ),
        },
      ),
    );
  }

  Widget _buildUsersTab() {
    final usersAsync = ref.watch(allUsersProvider);
    
    return usersAsync.when(
      data: (users) => Column(
        children: [
          _buildUsersHeader(users.length),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) => _buildUserCard(users[index]),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => Center(child: Text('خطأ: $error')),
    );
  }

  Widget _buildUsersHeader(int userCount) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إجمالي المستخدمين',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                '$userCount مستخدم',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ],
          ),
          CupertinoButton.filled(
            onPressed: _showAddUserDialog,
            child: const Text('إضافة مستخدم'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final role = perm.UserRole.fromName(user.role.name);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: user.isActive ? CupertinoColors.activeGreen : CupertinoColors.systemGrey,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              CupertinoIcons.person,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: const TextStyle(color: CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.activeBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: user.isActive ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.isActive ? 'نشط' : 'معطل',
                style: TextStyle(
                  fontSize: 10,
                  color: user.isActive ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showUserOptions(user),
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الأدوار والصلاحيات',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...perm.UserRole.allRoles.map((role) => _buildRoleCard(role)),
        ],
      ),
    );
  }

  Widget _buildRoleCard(perm.UserRole role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                role.displayName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'مستوى ${role.priority}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'الصلاحيات (${role.permissions.length}):',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: role.permissions.map((permission) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                permission.displayName,
                style: const TextStyle(
                  fontSize: 10,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return FutureBuilder<List<UserActivity>>(
      future: _activityService.getAllActivities(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }
        
        final activities = snapshot.data ?? [];
        
        return Column(
          children: [
            _buildActivityHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) => _buildActivityItem(activities[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityHeader() {
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
      child: const Row(
        children: [
          Icon(CupertinoIcons.clock, color: CupertinoColors.activeBlue),
          SizedBox(width: 12),
          Text(
            'سجل النشاط الأخير',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(UserActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getActivityColor(activity.activityType),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity.username} • ${activity.timeAgo}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.login:
      case ActivityType.logout:
        return CupertinoColors.activeGreen;
      case ActivityType.sale:
      case ActivityType.refund:
        return CupertinoColors.activeBlue;
      case ActivityType.addItem:
      case ActivityType.editItem:
      case ActivityType.deleteItem:
        return CupertinoColors.systemOrange;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  void _showUserOptions(User user) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(user.fullName),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('عرض التفاصيل'),
            onPressed: () {
              Navigator.pop(context);
              _showUserDetails(user);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('تعديل الصلاحيات'),
            onPressed: () {
              Navigator.pop(context);
              _showEditPermissions(user);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(user.isActive ? 'تعطيل المستخدم' : 'تفعيل المستخدم'),
            onPressed: () {
              Navigator.pop(context);
              _toggleUserStatus(user);
            },
          ),
          if (user.role.name != 'admin')
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('حذف المستخدم'),
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteUser(user);
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

  void _showAddUserDialog() {
    // سيتم تطوير نافذة إضافة مستخدم
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('إضافة مستخدم جديد'),
        content: const Text('سيتم تطوير هذه الميزة قريباً'),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(User user) {
    // سيتم تطوير شاشة تفاصيل المستخدم
  }

  void _showEditPermissions(User user) {
    // سيتم تطوير شاشة تعديل الصلاحيات
  }

  void _toggleUserStatus(User user) {
    // سيتم تطوير تفعيل/تعطيل المستخدم
  }

  void _confirmDeleteUser(User user) {
    // سيتم تطوير حذف المستخدم
  }
}
