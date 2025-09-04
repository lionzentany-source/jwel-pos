import 'package:fluent_ui/fluent_ui.dart';

/// AppBrandTheme: derives hover/pressed/focus/disabled colors from the current accent
/// Use AppBrandTheme.of(context) to access derived colors and helper styles.
class AppBrandTheme {
  final Color accent;
  final Color hover;
  final Color pressed;
  final Color focusStroke;
  final Color disabledBg;
  final Color disabledFg;

  const AppBrandTheme({
    required this.accent,
    required this.hover,
    required this.pressed,
    required this.focusStroke,
    required this.disabledBg,
    required this.disabledFg,
  });

  static AppBrandTheme of(BuildContext context) {
    final accentBase = FluentTheme.of(context).accentColor.normal;
    return fromAccent(accentBase);
  }

  static AppBrandTheme fromAccent(Color base) {
    final hsl = HSLColor.fromColor(base);
    Color lighten(double amount) =>
        hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
    Color darken(double amount) =>
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();

    final hover = lighten(0.08);
    final pressed = darken(0.12);
    final focusStroke = lighten(0.20).withValues(alpha: 0.6);
    final disabledBg = base.withValues(alpha: 0.45);
    final disabledFg = const Color(0xFF000000).withValues(alpha: 0.45);

    return AppBrandTheme(
      accent: base,
      hover: hover,
      pressed: pressed,
      focusStroke: focusStroke,
      disabledBg: disabledBg,
      disabledFg: disabledFg,
    );
  }

  /// Helper: primary filled button style using derived states
  ButtonStyle primaryFilledButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.isDisabled) return disabledBg;
        if (states.isPressed) return pressed;
        if (states.isHovered) return hover;
        return accent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.isDisabled) return disabledFg;
        return Colors.white;
      }),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(side: BorderSide(style: BorderStyle.none)),
      ),
    );
  }

  /// Secondary (outline) button style: transparent bg, accent border/text, hover fill
  ButtonStyle secondaryButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.isDisabled) return Colors.transparent;
        if (states.isHovered) return hover.withValues(alpha: 0.15);
        if (states.isPressed) return pressed.withValues(alpha: 0.2);
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.isDisabled) return disabledFg;
        return accent;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(side: BorderSide(color: accent, width: 1.2)),
      ),
    );
  }

  /// Hyperlink style: transparent background with accent text and underline on hover
  ButtonStyle hyperlinkStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.isDisabled) return disabledFg;
        return accent;
      }),
      textStyle: WidgetStateProperty.resolveWith((states) {
        final decoration = states.isHovered || states.isPressed
            ? TextDecoration.underline
            : TextDecoration.none;
        return TextStyle(decoration: decoration);
      }),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      ),
    );
  }

  /// Helper: subtle outline for focus visuals
  static Decoration focusOutline(BuildContext context) {
    final t = AppBrandTheme.of(context);
    return BoxDecoration(
      boxShadow: [
        BoxShadow(color: t.focusStroke, blurRadius: 6, spreadRadius: 0.5),
      ],
    );
  }
}
