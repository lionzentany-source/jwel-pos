import 'package:fluent_ui/fluent_ui.dart';

/// Shows a left-aligned side sheet (drawer-like) over the current page without
/// covering the whole screen. Useful for forms like Add/Edit item.
Future<T?> showSideSheet<T>(
  BuildContext context, {
  required Widget child,
  String? title,
  double width = 520,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? const Color(0x33000000),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(curve),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width,
                minWidth: width,
                maxHeight: MediaQuery.of(ctx).size.height,
              ),
              child: Acrylic(
                luminosityAlpha: 0.03,
                tintAlpha: 0.08,
                blurAmount: 12.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: FluentTheme.of(ctx).scaffoldBackgroundColor,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Small draggable/close header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(FluentIcons.chrome_close),
                                onPressed: () => Navigator.of(ctx).maybePop(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title ?? 'لوحة جانبية',
                                  style: FluentTheme.of(
                                    ctx,
                                  ).typography.bodyStrong,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(size: 1),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
