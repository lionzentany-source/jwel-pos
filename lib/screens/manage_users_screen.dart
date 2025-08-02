import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import '../utils/user_avatar_helper.dart';
import '../services/user_service.dart';

class ManageUsersScreen extends ConsumerWidget {
  const ManageUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final currentUser = ref.watch(userNotifierProvider).value;

    // التحقق من صلاحيات المدير
    if (currentUser?.role != UserRole.admin) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('إدارة المستخدمين'),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.lock_shield, size: 80, color: CupertinoColors.systemRed),
              SizedBox(height: 16),
              Text('ليس لديك صلاحية للوصول لهذه الصفحة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('هذه الصفحة مخصصة للمدير فقط',
                style: TextStyle(color: CupertinoColors.systemGrey)),
            ],
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('إدارة المستخدمين'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: () => _showAddUserDialog(context, ref),
        ),
      ),
      child: usersAsync.when(
        data: (users) => _buildUsersList(context, ref, users),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle,
                size: 50, color: CupertinoColors.systemRed),
              const SizedBox(height: 16),
              Text('خطأ في تحميل المستخدمين: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList(BuildContext context, WidgetRef ref, List<User> users) {
    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_3, size: 80, color: CupertinoColors.systemGrey),
            SizedBox(height: 16),
            Text('لا يوجد مستخدمين', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CupertinoListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    UserAvatarHelper.getUserColor(user),
                    UserAvatarHelper.getUserColor(user).withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                UserAvatarHelper.getUserIcon(user),
                color: CupertinoColors.white,
                size: 24,
              ),
            ),
            title: Text(user.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${user.username}',
                  style: const TextStyle(color: CupertinoColors.systemGrey)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: UserAvatarHelper.getUserColor(user).withValues(alpha: 0.1),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // أيقونة الحالة
                Icon(
                  user.isActive ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.xmark_circle_fill,
                  color: user.isActive ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                // زر الخيارات
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.ellipsis_vertical),
                  onPressed: () => _showUserOptions(context, ref, user),
                ),
              ],
            ),
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

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref, User user) {
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
                await UserService().changePassword(user.id!, passwordController.text);
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
        _showSuccessMessage(context, 
          user.isActive ? 'تم إلغاء تفعيل المستخدم' : 'تم تفعيل المستخدم');
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
        content: Text('هل أنت متأكد من حذف المستخدم "${user.fullName}"؟\nهذا الإجراء لا يمكن التراجع عنه.'),
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
            Icon(CupertinoIcons.check_mark_circled, color: CupertinoColors.systemGreen),
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
            Icon(CupertinoIcons.exclamationmark_triangle, color: CupertinoColors.systemRed),
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
