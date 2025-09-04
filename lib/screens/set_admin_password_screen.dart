import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/first_run_service.dart';
import 'main_navigation_screen.dart';

class SetAdminPasswordScreen extends ConsumerStatefulWidget {
  const SetAdminPasswordScreen({super.key});

  @override
  ConsumerState<SetAdminPasswordScreen> createState() =>
      _SetAdminPasswordScreenState();
}

class _SetAdminPasswordScreenState
    extends ConsumerState<SetAdminPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    final p1 = _passwordController.text.trim();
    final p2 = _confirmController.text.trim();
    if (p1.isEmpty || p2.isEmpty) {
      setState(() {
        _error = 'الرجاء إدخال كلمة المرور وتأكيدها';
        _saving = false;
      });
      return;
    }
    if (p1 != p2) {
      setState(() {
        _error = 'كلمتا المرور غير متطابقتين';
        _saving = false;
      });
      return;
    }
    if (p1.length < 8) {
      setState(() {
        _error = 'يجب أن تكون كلمة المرور 8 أحرف على الأقل';
        _saving = false;
      });
      return;
    }

    final service = FirstRunService();
    final ok = await service.completeAdminPasswordSetup(p1);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        FluentPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } else {
      setState(() {
        _error = 'تعذر حفظ كلمة المرور. حاول مرة أخرى';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('تعيين كلمة مرور المدير')),
      content: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'لأمان أعلى، الرجاء تعيين كلمة مرور جديدة لحساب المدير',
                    style: FluentTheme.of(context).typography.body,
                  ),
                  const SizedBox(height: 16),
                  InfoBar(
                    title: const Text('ملاحظة مهمة'),
                    content: const Text(
                      'لن يُطلب منك هذا الإجراء مرة أخرى بعد الحفظ',
                    ),
                    severity: InfoBarSeverity.info,
                  ),
                  const SizedBox(height: 16),
                  TextBox(
                    placeholder: 'كلمة المرور الجديدة',
                    obscureText: true,
                    controller: _passwordController,
                  ),
                  const SizedBox(height: 12),
                  TextBox(
                    placeholder: 'تأكيد كلمة المرور',
                    obscureText: true,
                    controller: _confirmController,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InfoBar(
                        title: const Text('خطأ'),
                        content: Text(_error!),
                        severity: InfoBarSeverity.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const ProgressRing()
                        : const Text('حفظ والمتابعة'),
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
