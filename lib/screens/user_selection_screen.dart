import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import '../utils/user_avatar_helper.dart';
import 'pos_screen.dart';

class UserSelectionScreen extends ConsumerWidget {
  const UserSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'اختر المستخدم',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Color(0xFFF2F2F7),
      ),
      child: SafeArea(
        child: usersAsync.when(
          data: (users) => _buildUserGrid(users),
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(radius: 20),
                SizedBox(height: 16),
                Text(
                  'جاري تحميل المستخدمين...',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 50,
                  color: CupertinoColors.systemRed,
                ),
                const SizedBox(height: 16),
                Text(
                  'خطأ في تحميل المستخدمين',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: const TextStyle(color: CupertinoColors.systemGrey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserGrid(List<User> users) {
    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.person_3,
              size: 80,
              color: CupertinoColors.systemGrey,
            ),
            SizedBox(height: 16),
            Text(
              'لا يوجد مستخدمين',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => UserCard(user: users[index]),
              childCount: users.length,
            ),
          ),
        ),
      ],
    );
  }
}

class UserCard extends ConsumerStatefulWidget {
  const UserCard({super.key, required this.user});

  final User user;

  @override
  ConsumerState<UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<UserCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              _animationController.forward();
            },
            onTapUp: (_) {
              _animationController.reverse();
              _showPasswordDialog(context, ref, widget.user);
            },
            onTapCancel: () {
              _animationController.reverse();
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CupertinoColors.white,
                    CupertinoColors.white.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: UserAvatarHelper.getUserColor(
                    widget.user,
                  ).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // أيقونة المستخدم
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            UserAvatarHelper.getUserColor(widget.user),
                            UserAvatarHelper.getUserColor(
                              widget.user,
                            ).withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: UserAvatarHelper.getUserColor(
                              widget.user,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        UserAvatarHelper.getUserIcon(widget.user),
                        size: 20,
                        color: CupertinoColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // اسم المستخدم
                    Text(
                      widget.user.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // دور المستخدم
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: UserAvatarHelper.getUserColor(
                          widget.user,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.user.role.displayName,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: UserAvatarHelper.getUserColor(widget.user),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPasswordDialog(BuildContext context, WidgetRef ref, User user) {
    final passwordController = TextEditingController();

    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CupertinoAlertDialog(
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      UserAvatarHelper.getUserColor(user),
                      UserAvatarHelper.getUserColor(
                        user,
                      ).withValues(alpha: 0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  UserAvatarHelper.getUserIcon(user),
                  size: 20,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      user.role.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: UserAvatarHelper.getUserColor(user),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'ادخل كلمة المرور للمتابعة',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: passwordController,
                obscureText: true,
                placeholder: 'كلمة المرور',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                autofocus: true,
                onSubmitted: (_) => _handleLogin(
                  context,
                  ref,
                  user,
                  passwordController,
                  setState,
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: CupertinoColors.systemGrey),
              ),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: isLoading
                  ? null
                  : () => _handleLogin(
                      context,
                      ref,
                      user,
                      passwordController,
                      setState,
                    ),
              child: isLoading
                  ? const CupertinoActivityIndicator()
                  : const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin(
    BuildContext context,
    WidgetRef ref,
    User user,
    TextEditingController passwordController,
    StateSetter setState,
  ) async {
    setState(() => isLoading = true);
    try {
      final success = await ref
          .read(userNotifierProvider.notifier)
          .authenticate(user.username, passwordController.text);

      if (success && context.mounted) {
        // نغلق حوار كلمة المرور أولاً قبل التنقل
        final rootNavigator = Navigator.of(context, rootNavigator: true);
        rootNavigator.pop(); // إغلاق الحوار

        // جدولة الانتقال في الإطار التالي لتفادي مشاكل تراكب الحوار
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          rootNavigator.pushReplacement(
            CupertinoPageRoute(builder: (_) => const PosScreen()),
          );
        });
      } else if (context.mounted) {
        setState(() => isLoading = false);
        _showErrorDialog(context, 'كلمة المرور غير صحيحة');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (context.mounted) {
        setState(() => isLoading = false);
        _showErrorDialog(context, 'حدث خطأ أثناء تسجيل الدخول');
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Row(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: CupertinoColors.systemRed,
              size: 24,
            ),
            SizedBox(width: 8),
            Text('خطأ'),
          ],
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}
