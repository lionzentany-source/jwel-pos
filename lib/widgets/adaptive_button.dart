import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const AdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return CupertinoButton(
        color: isPrimary ? CupertinoColors.activeBlue : CupertinoColors.systemGrey,
        onPressed: onPressed,
        child: Text(label),
      );
    } else {
      return ElevatedButton(
        onPressed: onPressed,
        style: isPrimary
            ? ElevatedButton.styleFrom()
            : ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
        child: Text(label),
      );
    }
  }
}
