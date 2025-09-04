import 'package:fluent_ui/fluent_ui.dart';
import '../theme/app_brand_theme.dart';

/// Unified buttons for a consistent look across the app
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final _AppButtonKind _kind;
  final double? width;
  final double height;

  const AppButton._({
    super.key,
    required this.text,
    required this.onPressed,
    required _AppButtonKind kind,
    this.icon,
    this.width,
    this.height = 48,
  }) : _kind = kind;

  factory AppButton.primary({
    Key? key,
    required String text,
    IconData? icon,
    VoidCallback? onPressed,
    double? width,
    double height = 48,
  }) => AppButton._(
    key: key,
    text: text,
    icon: icon,
    onPressed: onPressed,
    kind: _AppButtonKind.primary,
    width: width,
    height: height,
  );

  factory AppButton.secondary({
    Key? key,
    required String text,
    IconData? icon,
    VoidCallback? onPressed,
    double? width,
    double height = 48,
  }) => AppButton._(
    key: key,
    text: text,
    icon: icon,
    onPressed: onPressed,
    kind: _AppButtonKind.secondary,
    width: width,
    height: height,
  );

  factory AppButton.destructive({
    Key? key,
    required String text,
    IconData? icon,
    VoidCallback? onPressed,
    double? width,
    double height = 48,
  }) => AppButton._(
    key: key,
    text: text,
    icon: icon,
    onPressed: onPressed,
    kind: _AppButtonKind.destructive,
    width: width,
    height: height,
  );

  static Widget nav({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Builder(
      builder: (context) {
        final t = AppBrandTheme.of(context);
        return FilledButton(
          onPressed: onPressed,
          style: t.primaryFilledButtonStyle().merge(
            ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xffffffff)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xffffffff),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(FluentIcons.chevron_right, color: Color(0xff99ebff)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );

    final style = switch (_kind) {
      _AppButtonKind.primary => AppBrandTheme.of(
        context,
      ).primaryFilledButtonStyle(),
      _AppButtonKind.secondary => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          FluentTheme.of(context).micaBackgroundColor,
        ),
      ),
      _AppButtonKind.destructive => ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.red),
        foregroundColor: WidgetStateProperty.all(const Color(0xffffffff)),
      ),
    };

    final button = switch (_kind) {
      _AppButtonKind.primary => FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      _AppButtonKind.secondary => Button(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      _AppButtonKind.destructive => Button(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    };

    return SizedBox(width: width, height: height, child: button);
  }
}

enum _AppButtonKind { primary, secondary, destructive }
