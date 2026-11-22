import 'package:flutter/animation.dart';

/// Material 3 motion tokens, used by every Vega animation so timing feels uniform.
class VegaMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 500);
  static const Duration ambient = Duration(milliseconds: 2600);

  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve standard = Curves.easeInOut;
  static const Curve decelerate = Curves.easeOutCubic;
}
