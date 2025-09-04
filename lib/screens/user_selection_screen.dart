import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import '../utils/user_avatar_helper.dart';
import 'main_navigation_screen.dart';
import 'set_admin_password_screen.dart';
import '../repositories/settings_repository.dart';
import '../widgets/branded_logo.dart';
import '../widgets/adaptive_scaffold.dart';

class UserSelectionScreen extends ConsumerWidget {
  const UserSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return AdaptiveScaffold(
      title: 'اختر المستخدم',
      backgroundColor: const Color(0xfff6f8fa),
      showBackButton: false,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                BrandedLogo(size: 90),
                const SizedBox(height: 16),
                Text(
                  'اختر المستخدم',
                  style: FluentTheme.of(context).typography.title,
                ),
              ],
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) {
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
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              FluentPageRoute(
                                builder: (_) => const CreateAdminScreen(),
                              ),
                            );
                            ref.invalidate(allUsersProvider);
                          },
                          child: const Text('إنشاء مستخدم مدير'),
                        ),
                      ],
                    ),
                  );
                }
                return _buildUserGrid(users);
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ProgressRing(),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحميل المستخدمين...',
                      style: FluentTheme.of(context).typography.body,
                    ),
                  ],
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.error, size: 50, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'خطأ في تحميل المستخدمين',
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrid(List<User> users) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive grid based on screen width
          final crossAxisCount = constraints.maxWidth > 800
              ? 4
              : constraints.maxWidth > 600
              ? 3
              : 2;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: users.length,
            itemBuilder: (context, index) => UserCard(user: users[index]),
          );
        },
      ),
    );
  }
}

// Removed local logo widget in favor of shared BrandedLogo

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
            child: Card(
              backgroundColor: FluentTheme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: UserAvatarHelper.getUserColor(
                      widget.user,
                    ).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  // Subtle gradient overlay for depth
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FluentTheme.of(context).cardColor,
                      FluentTheme.of(context).cardColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // User avatar with Fluent Design styling
                      Container(
                        width: 48,
                        height: 48,
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
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // User name with Fluent typography
                      Text(
                        widget.user.fullName,
                        textAlign: TextAlign.center,
                        style: FluentTheme.of(context).typography.body
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // User role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: UserAvatarHelper.getUserColor(
                            widget.user,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.user.role.displayName,
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                color: UserAvatarHelper.getUserColor(
                                  widget.user,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
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

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => ContentDialog(
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    Text(
                      user.role.displayName,
                      style: FluentTheme.of(context).typography.caption
                          ?.copyWith(
                            color: UserAvatarHelper.getUserColor(user),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                'ادخل كلمة المرور للمتابعة',
                style: FluentTheme.of(context).typography.body,
              ),
              const SizedBox(height: 16),
              TextBox(
                controller: passwordController,
                obscureText: true,
                placeholder: 'كلمة المرور',
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
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () => _handleLogin(
                      context,
                      ref,
                      user,
                      passwordController,
                      setState,
                    ),
              child: isLoading ? const ProgressRing() : const Text('دخول'),
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
      // Capture root navigator early
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final success = await ref
          .read(userNotifierProvider.notifier)
          .authenticate(user.username, passwordController.text);

      if (success && context.mounted) {
        // تحقق من شرط تعيين كلمة مرور المدير للمرة الأولى
        final settingsRepo = SettingsRepository();
        final requireAdminPwd = await settingsRepo.getBoolFlag(
          SettingsRepository.kRequireAdminPasswordSetup,
          defaultValue: false,
        );
        // نغلق حوار كلمة المرور أولاً قبل التنقل
        rootNavigator.pop(); // إغلاق الحوار

        // جدولة الانتقال في الإطار التالي لتفادي مشاكل تراكب الحوار
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // إذا كان المستخدم هو المدير والفلاغ مفعّل -> انتقل لشاشة ضبط كلمة المرور
          if (user.username == 'admin' && requireAdminPwd) {
            rootNavigator.pushReplacement(
              FluentPageRoute(builder: (_) => const SetAdminPasswordScreen()),
            );
          } else {
            rootNavigator.pushReplacement(
              FluentPageRoute(builder: (_) => const MainNavigationScreen()),
            );
          }
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
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Row(
          children: [
            Icon(FluentIcons.error, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text('خطأ'),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

// شاشة إنشاء مستخدم مدير (كاملة)
class CreateAdminScreen extends ConsumerStatefulWidget {
  const CreateAdminScreen({super.key});

  @override
  ConsumerState<CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends ConsumerState<CreateAdminScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _saveAdmin(BuildContext context) async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();
    if (username.isEmpty || password.isEmpty || fullName.isEmpty) {
      setState(() {
        _error = 'جميع الحقول مطلوبة';
        _isLoading = false;
      });
      return;
    }
    try {
      final userNotifier = ref.read(userNotifierProvider.notifier);
      await userNotifier.createAdminUser(
        username: username,
        password: password,
        fullName: fullName,
      );
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ أثناء الحفظ';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(title: const Text('إنشاء مستخدم مدير')),
      content: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'أدخل بيانات المدير الأول للنظام',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 24),
                  TextBox(
                    controller: _usernameController,
                    placeholder: 'اسم المستخدم',
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextBox(
                    controller: _passwordController,
                    placeholder: 'كلمة المرور',
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextBox(
                    controller: _fullNameController,
                    placeholder: 'الاسم الكامل',
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InfoBar(
                        title: const Text('خطأ'),
                        content: Text(_error!),
                        severity: InfoBarSeverity.error,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : () => _saveAdmin(context),
                      child: _isLoading
                          ? const ProgressRing()
                          : const Text('حفظ وإنشاء المدير'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
