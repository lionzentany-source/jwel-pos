import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../models/user.dart';
import '../models/user_permission.dart';
import '../models/user_activity.dart';
import '../services/user_activity_service.dart';
import '../providers/user_provider.dart';

class AdvancedUserManagementScreen extends ConsumerStatefulWidget {
  const AdvancedUserManagementScreen({super.key});

  @override
  ConsumerState<AdvancedUserManagementScreen> createState() =>
      _AdvancedUserManagementScreenState();
}

class _AdvancedUserManagementScreenState
    extends ConsumerState<AdvancedUserManagementScreen> {
  final UserActivityService _activityService = UserActivityService();
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
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
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xffffffff), // أبيض نقي للبطاقات
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Color(0xff0078d4).withAlpha(20),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
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
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: Color(0xffffffff),
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
                  color: Color(0xff0078D4),
                ),
              ),
            ],
          ),
          AdaptiveButton(text: 'إضافة مستخدم', onPressed: _showAddUserDialog),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final role = UserRole.values.firstWhere(
      (e) => e.name == user.role.name,
      orElse: () => UserRole.cashier,
    );

    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: Color(0xffffffff),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: user.isActive
                  ? CupertinoColors.activeGreen
                  : CupertinoColors.systemGrey,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(CupertinoIcons.person, color: CupertinoColors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: const TextStyle(color: CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                  color: user.isActive
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.isActive ? 'نشط' : 'معطل',
                style: TextStyle(
                  fontSize: 10,
                  color: user.isActive
                      ? CupertinoColors.activeGreen
                      : CupertinoColors.systemRed,
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
          ...UserRole.values.map((role) => _buildRoleCard(role)),
        ],
      ),
    );
  }

  Widget _buildRoleCard(UserRole role) {
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: Color(0xffffffff),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                role.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
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
            children: role.permissions
                .map(
                  (permission) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                  ),
                )
                .toList(),
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
                itemBuilder: (context, index) =>
                    _buildActivityItem(activities[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityHeader() {
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: Color(0xffffffff),
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
    return AdaptiveCard(
      padding: const EdgeInsets.all(12),
      backgroundColor: Color(0xffffffff),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xfff6f8fa),
        title: Text(user.fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdaptiveButton(
              text: 'عرض التفاصيل',
              onPressed: () {
                Navigator.pop(context);
                _showUserDetails(user);
              },
            ),
            AdaptiveButton(
              text: 'تعديل الصلاحيات',
              onPressed: () {
                Navigator.pop(context);
                _showEditPermissions(user);
              },
            ),
            AdaptiveButton(
              text: user.isActive ? 'تعطيل المستخدم' : 'تفعيل المستخدم',
              onPressed: () {
                Navigator.pop(context);
                _toggleUserStatus(user);
              },
            ),
            if (user.role.name != 'admin')
              AdaptiveButton(
                text: 'حذف المستخدم',
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteUser(user);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController();
    UserRole selectedRole = UserRole.manager;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xfff6f8fa),
          title: const Text('إضافة مستخدم جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  obscureText: true,
                ),
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                ),
                DropdownButton<UserRole>(
                  value: selectedRole,
                  items: UserRole.values
                      .where((r) => r != UserRole.admin)
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (role) {
                    if (role != null) setState(() => selectedRole = role);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('حفظ'),
              onPressed: () async {
                try {
                  final userService = ref.read(userServiceProvider);
                  await userService.createUser(
                    username: usernameController.text.trim(),
                    password: passwordController.text.trim(),
                    fullName: fullNameController.text.trim(),
                    role: selectedRole,
                  );
                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true).pop();
                  setState(() {});
                } catch (e) {
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('خطأ'),
                      content: Text(e.toString()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text('موافق'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xfff6f8fa),
        title: Text('تفاصيل المستخدم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاسم الكامل: ${user.fullName}'),
            Text('اسم المستخدم: @${user.username}'),
            Text('الدور: ${user.role.displayName}'),
            Text('الحالة: ${user.isActive ? 'نشط' : 'معطل'}'),
            Text('تاريخ الإنشاء: ${user.createdAt.toLocal()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showEditPermissions(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xfff6f8fa),
        title: Text('تعديل صلاحيات المستخدم'),
        content: Text('تغيير الدور الحالي: ${user.role.displayName}'),
        actions: [
          ...UserRole.values
              .where((r) => r != UserRole.admin)
              .map(
                (role) => TextButton(
                  child: Text(role.displayName),
                  onPressed: () async {
                    final userService = ref.read(userServiceProvider);
                    await userService.updateUser(userId: user.id!, role: role);
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pop();
                    setState(() {});
                  },
                ),
              ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _toggleUserStatus(User user) {
    final newStatus = !user.isActive;
    final userService = ref.read(userServiceProvider);
    userService.updateUser(userId: user.id!, isActive: newStatus).then((_) {
      setState(() {});
    });
  }

  void _confirmDeleteUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xfff6f8fa),
        title: Text('تأكيد حذف المستخدم'),
        content: Text('هل أنت متأكد أنك تريد حذف المستخدم ${user.fullName}؟'),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final userService = ref.read(userServiceProvider);
              await userService.deleteUser(user.id!);
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pop();
              setState(() {});
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
