import 'package:flutter/cupertino.dart';

class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Color? backgroundColor;
  final bool showBackButton;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
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
    return CupertinoPageScaffold(
      backgroundColor:
          backgroundColor ?? CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: title != null ? Text(title!) : null,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
            : null,
        automaticallyImplyLeading: showBackButton,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 32.0 : 16.0,
            vertical: 16.0,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          backgroundColor ?? CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: title != null ? Text(title!) : null,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
            : null,
        automaticallyImplyLeading: showBackButton,
      ),
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16.0), child: body),
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
      child: CupertinoButton.filled(
        onPressed: onPressed,
        color: isDestructive
            ? CupertinoColors.destructiveRed
            : (color ?? CupertinoColors.activeBlue),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor ?? CupertinoColors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                color: textColor ?? CupertinoColors.white,
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
      child: Container(
        padding: padding ?? const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: backgroundColor ?? CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
