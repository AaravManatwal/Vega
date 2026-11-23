import 'package:flutter/material.dart';

/// The Vega app logo (same artwork as the launcher icon).
class VegaLogo extends StatelessWidget {
  final double size;

  /// Kept for existing callers; the artwork has its own rounded edge.
  final bool showBorder;

  const VegaLogo({
    super.key,
    this.size = 36,
    this.showBorder = true,
  });

  static const String asset = 'assets/branding/vega_logo.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vega',
      image: true,
      child: ExcludeSemantics(
        child: Image.asset(
          asset,
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
      ),
    );
  }
}
