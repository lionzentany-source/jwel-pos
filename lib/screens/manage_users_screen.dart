import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import '../utils/user_avatar_helper.dart';
import '../services/user_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../widgets/adaptive_scaffold.dart';

class ManageUsersScreen extends ConsumerWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final currentUser = ref.watch(userNotifierProvider).value;

    if (currentUser?.role != UserRole.admin) {
      return AdaptiveScaffold(
        title: 'إدارة المستخدمين',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.lock, size: 80, color: Color(0xFF0078D4)),
              const SizedBox(height: 16),
              Text(
                'ليس لديك صلاحية للوصول لهذه الصفحة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'هذه الصفحة مخصصة للمدير فقط',
                style: TextStyle(color: Color(0xFF106EBE)),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xfff6f8fa),
      );
    }

    return AdaptiveScaffold(
      title: 'إدارة المستخدمين',
      commandBarItems: [
        CommandBarButton(
          icon: const Icon(FluentIcons.add, size: 20),
          label: const Text(
            'إضافة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          onPressed: () => _showAddUserDialog(context, ref),
        ),
      ],
      backgroundColor: const Color(0xfff6f8fa),
      body: usersAsync.when(
        data: (users) => _buildUsersList(context, ref, users),
        loading: () => const Center(child: ProgressRing()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.error, size: 50, color: Colors.red),
              const SizedBox(height: 16),
              Text('خطأ في تحميل المستخدمين: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList(
    BuildContext context,
    WidgetRef ref,
    List<User> users,
  ) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.people,
              size: 80,
              color: FluentTheme.of(context).inactiveColor,
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد مستخدمين',
              style: FluentTheme.of(context).typography.subtitle,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return AdaptiveCard(
          padding: const EdgeInsets.all(16),
          backgroundColor: Color(0xffffffff),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      UserAvatarHelper.getUserColor(user),
                      UserAvatarHelper.getUserColor(user).withAlpha(179),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  UserAvatarHelper.getUserIcon(user),
                  color: Color(0xFFFFFFFF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '@${user.username}',
                      style: TextStyle(color: Color(0xFF106EBE)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: UserAvatarHelper.getUserColor(
                          user,
                        ).withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.role.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: UserAvatarHelper.getUserColor(user),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    user.isActive ? FluentIcons.check_mark : FluentIcons.cancel,
                    color: user.isActive ? Color(0xFF22C55E) : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.isActive ? 'نشط' : 'معطل',
                    style: TextStyle(
                      fontSize: 10,
                      color: user.isActive ? Color(0xFF22C55E) : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () => _showUserOptions(context, ref, user),
                child: const Icon(FluentIcons.more),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUserOptions(BuildContext context, WidgetRef ref, User user) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('خيارات ${user.fullName}'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('تعديل المستخدم'),
            onPressed: () {
              Navigator.pop(context);
              _showEditUserDialog(context, ref, user);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('تغيير كلمة المرور'),
            onPressed: () {
              Navigator.pop(context);
              _showChangePasswordDialog(context, ref, user);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(user.isActive ? 'إلغاء تفعيل' : 'تفعيل'),
            onPressed: () {
              Navigator.pop(context);
              _toggleUserStatus(context, ref, user);
            },
          ),
          if (user.username != 'admin') // لا يمكن حذف المدير الرئيسي
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('حذف المستخدم'),
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, ref, user);
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

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final usernameController = TextEditingController();
    final fullNameController = TextEditingController();
    final passwordController = TextEditingController();
    UserRole selectedRole = UserRole.cashier;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CupertinoAlertDialog(
          title: const Text('إضافة مستخدم جديد'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: usernameController,
                placeholder: 'اسم المستخدم',
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: fullNameController,
                placeholder: 'الاسم الكامل',
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: passwordController,
                placeholder: 'كلمة المرور',
                obscureText: true,
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              // اختيار الدور
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('الدور: '),
                    Expanded(
                      child: CupertinoSlidingSegmentedControl<UserRole>(
                        children: const {
                          UserRole.admin: Text('مدير'),
                          UserRole.manager: Text('مدير عام'),
                          UserRole.cashier: Text('بائع'),
                          UserRole.supervisor: Text('مشرف'),
                        },
                        onValueChanged: (value) {
                          setState(() => selectedRole = value!);
                        },
                        groupValue: selectedRole,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('إضافة'),
              onPressed: () async {
                try {
                  await UserService().createUser(
                    username: usernameController.text,
                    password: passwordController.text,
                    fullName: fullNameController.text,
                    role: selectedRole,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(allUsersProvider);
                    _showSuccessMessage(context, 'تم إضافة المستخدم بنجاح');
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showErrorMessage(context, 'خطأ في إضافة المستخدم: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, WidgetRef ref, User user) {
    final fullNameController = TextEditingController(text: user.fullName);
    UserRole selectedRole = user.role;

    showCupertinoDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CupertinoAlertDialog(
          title: Text('تعديل ${user.fullName}'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: fullNameController,
                placeholder: 'الاسم الكامل',
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('الدور: '),
                    Expanded(
                      child: CupertinoSlidingSegmentedControl<UserRole>(
                        children: const {
                          UserRole.admin: Text('مدير'),
                          UserRole.manager: Text('مدير عام'),
                          UserRole.cashier: Text('بائع'),
                          UserRole.supervisor: Text('مشرف'),
                        },
                        onValueChanged: (value) {
                          setState(() => selectedRole = value!);
                        },
                        groupValue: selectedRole,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('حفظ'),
              onPressed: () async {
                try {
                  await UserService().updateUser(
                    userId: user.id!,
                    fullName: fullNameController.text,
                    role: selectedRole,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(allUsersProvider);
                    _showSuccessMessage(context, 'تم تحديث المستخدم بنجاح');
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showErrorMessage(context, 'خطأ في تحديث المستخدم: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) {
    final passwordController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('تغيير كلمة مرور ${user.fullName}'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: passwordController,
              placeholder: 'كلمة المرور الجديدة',
              obscureText: true,
              padding: const EdgeInsets.all(12),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('تغيير'),
            onPressed: () async {
              try {
                await UserService().changePassword(
                  user.id!,
                  passwordController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessMessage(context, 'تم تغيير كلمة المرور بنجاح');
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorMessage(context, 'خطأ في تغيير كلمة المرور: $e');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _toggleUserStatus(BuildContext context, WidgetRef ref, User user) async {
    try {
      await UserService().updateUser(
        userId: user.id!,
        isActive: !user.isActive,
      );
      ref.invalidate(allUsersProvider);
      if (context.mounted) {
        _showSuccessMessage(
          context,
          user.isActive ? 'تم إلغاء تفعيل المستخدم' : 'تم تفعيل المستخدم',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorMessage(context, 'خطأ في تحديث حالة المستخدم: $e');
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, User user) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف المستخدم "${user.fullName}"?\nهذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('حذف'),
            onPressed: () async {
              try {
                await UserService().deleteUser(user.id!);
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(allUsersProvider);
                  _showSuccessMessage(context, 'تم حذف المستخدم بنجاح');
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorMessage(context, 'خطأ في حذف المستخدم: $e');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Row(
          children: [
            Icon(
              CupertinoIcons.check_mark_circled,
              color: CupertinoColors.systemGreen,
            ),
            SizedBox(width: 8),
            Text('نجح'),
          ],
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('حسناً'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Row(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: CupertinoColors.systemRed,
            ),
            SizedBox(width: 8),
            Text('خطأ'),
          ],
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('حسناً'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
