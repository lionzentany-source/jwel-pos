import 'package:flutter/cupertino.dart';

/// Reusable company logo widget.
/// Looks for a square transparent logo `assets/images/logo_square.png`.
/// Falls back to the original provided image if the square one is missing.
class BrandedLogo extends StatelessWidget {
  final double size;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final bool monochrome;

  const BrandedLogo({
    super.key,
    this.size = 72,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.fit = BoxFit.contain,
    this.monochrome = false,
  });

  @override
  Widget build(BuildContext context) {
    // Paths (developer must add the square & bw assets manually)
    const squarePath = 'assets/images/logo_square.png';
    const originalPath =
        'assets/images/475686060_122111624468716899_7070205537672805384_n.jpg';
    const bwPath = 'assets/images/logo_bw.png';

    final chosen = monochrome ? bwPath : squarePath;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        chosen,
        height: size,
        width: size,
        fit: fit,
        // If square/bw not found, this errorBuilder swaps to original image.
        errorBuilder: (_, __, ___) =>
            Image.asset(originalPath, height: size, width: size, fit: fit),
      ),
    );
  }
}
