import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../widgets/adaptive_scaffold.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'pos_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'admin123',
  );
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final username = _usernameController.text;
    final password = _passwordController.text;

    // Debugging prints
    debugPrint("--- ATTEMPTING LOGIN ---");
    debugPrint("Username from controller: '$username'");
    debugPrint("Password from controller: '$password'");

    final success = await ref
        .read(userNotifierProvider.notifier)
        .authenticate(username, password);

    if (success) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (context) => const PosScreen()),
        );
      }
    } else {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Login Failed'),
            content: const Text('Invalid username or password.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xfff6f8fa),
      child: AdaptiveScaffold(
        title: 'تسجيل الدخول',
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: AdaptiveCard(
              backgroundColor: const Color(0xffffffff),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'أهلاً بك في النظام',
                    style: FluentTheme.of(context).typography.title,
                  ),
                  const SizedBox(height: 24),
                  InfoBar(
                    title: const Text('تنبيه أول تشغيل'),
                    content: const Text(
                      'عند الدخول بحساب المدير لأول مرة سيتم طلب تعيين كلمة مرور جديدة لمرة واحدة.',
                    ),
                    severity: InfoBarSeverity.info,
                  ),
                  const SizedBox(height: 12),
                  TextBox(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    placeholder: 'اسم المستخدم',
                    autofocus: true,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  TextBox(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    placeholder: 'كلمة المرور',
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const ProgressRing()
                      : AdaptiveButton(
                          text: 'دخول',
                          color: const Color(0xFF0078D4),
                          textColor: const Color(0xFFFFFFFF),
                          onPressed: _login,
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
