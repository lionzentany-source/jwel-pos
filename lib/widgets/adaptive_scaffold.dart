import 'package:fluent_ui/fluent_ui.dart';

class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final Widget? titleWidget; // Custom title widget (optional)
  final Widget? leading; // Custom leading widget (optional)
  final List<Widget>?
  actions; // Deprecated for Fluent CommandBar; keep for compatibility
  final List<CommandBarItem>? commandBarItems; // Preferred Fluent action model
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Color? backgroundColor;
  final bool showBackButton;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.commandBarItems,
    this.floatingActionButton,
    this.drawer,
    this.backgroundColor,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // تحديد ما إذا كان الجهاز تابلت أم لا
        final isTablet = constraints.maxWidth > 600;
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        if (isTablet) {
          return _buildTabletLayout(context, isLandscape);
        } else {
          return _buildPhoneLayout(context);
        }
      },
    );
  }

  Widget _buildTabletLayout(BuildContext context, bool isLandscape) {
    final canPop = Navigator.of(context).canPop();
    final headerLeading =
        leading ??
        ((showBackButton && canPop)
            ? IconButton(
                icon: const Icon(FluentIcons.back, size: 20),
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
              )
            : null);
    // Enlarge command bar controls for touch on tablets
    Widget? commandBarWidget;
    if (commandBarItems != null && commandBarItems!.isNotEmpty) {
      commandBarWidget = IconTheme(
        data: const IconThemeData(size: 20),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          child: CommandBar(primaryItems: commandBarItems!),
        ),
      );
    }

    return ScaffoldPage(
      header: PageHeader(
        leading: headerLeading,
        title: titleWidget ?? (title != null ? Text(title!) : null),
        commandBar: commandBarWidget,
      ),
      content: Container(
        color:
            backgroundColor ?? FluentTheme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 32.0 : 16.0,
              vertical: 16.0,
            ),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final headerLeading =
        leading ??
        ((showBackButton && canPop)
            ? IconButton(
                icon: const Icon(FluentIcons.back, size: 20),
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
              )
            : null);
    Widget? commandBarWidget;
    if (commandBarItems != null && commandBarItems!.isNotEmpty) {
      commandBarWidget = IconTheme(
        data: const IconThemeData(size: 18),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          child: CommandBar(primaryItems: commandBarItems!),
        ),
      );
    }
    return ScaffoldPage(
      header: PageHeader(
        leading: headerLeading,
        title: titleWidget ?? (title != null ? Text(title!) : null),
        commandBar: commandBarWidget,
      ),
      content: Container(
        color:
            backgroundColor ?? FluentTheme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Padding(padding: const EdgeInsets.all(16.0), child: body),
        ),
      ),
    );
  }
}

// Widget مخصص للأزرار الكبيرة المناسبة للمس
class AdaptiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final bool isDestructive;
  final double? width;
  final double? height;

  const AdaptiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.textColor,
    this.icon,
    this.isDestructive = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? 50.0, // الحد الأدنى للمس المريح
      child: isDestructive
          ? Button(
              onPressed: onPressed,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.red),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: textColor ?? Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : FilledButton(
              onPressed: onPressed,
              style: ButtonStyle(
                backgroundColor: color != null
                    ? WidgetStateProperty.all(color)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: textColor ?? Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Widget للبطاقات المتجاوبة
class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        padding: padding ?? const EdgeInsets.all(16.0),
        backgroundColor: backgroundColor ?? FluentTheme.of(context).cardColor,
        child: child,
      ),
    );
  }
}

// Widget للنصوص المتجاوبة
class AdaptiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AdaptiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        return Text(
          text,
          style: style?.copyWith(
            fontSize: isTablet
                ? (style?.fontSize ?? 16) * 1.2
                : style?.fontSize,
          ),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
