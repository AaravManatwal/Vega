import 'package:flutter/material.dart';

/// Brand colors. The Material 3 schemes are generated from these in vega_scheme.dart.
class VegaColors {
  // VEGA Rajasthani Heritage Deep Navy & Electric Blue Palette + Gold-Leaf (#C5A059)
  static const Color deepCanvas = Color(0xFF06132B);
  static const Color deepNavy = Color(0xFF0A1F44);
  static const Color cardMidnight = Color(0xFF0B2552);
  static const Color borderMidnight = Color(0xFF1E3A6B);
  static const Color midnightBlue = Color(0xFF003366);
  static const Color electricBlue = Color(0xFF007AFF);
  static const Color vibrantOrange = Color(0xFF007AFF);
  static const Color skyAccent = Color(0xFFC5A059); // Gold-Leaf Accent
  static const Color lightSky = Color(0xFFDBEAFE);

  // Dedicated Gold-Leaf Heritage Tokens
  static const Color sandstoneGold = Color(0xFFC5A059);
  static const Color goldHighlight = Color(0xFFE4C788);
  static const Color bandhaniMaroon = Color(0xFF003366);
  static const Color peacockBlue = Color(0xFF007AFF);

  static const Color lightBackground = Color(0xFFF6F4EE); // Warm Ivory
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkBackground = deepCanvas;
  static const Color darkSurface = deepNavy;

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);

  /// Button blue. Electric blue with white text is only 4:1; this reaches 5.3:1.
  static const Color actionBlue = Color(0xFF0062DB);

  /// Readable text/icon tones on the dark navy surfaces (all above 4.5:1).
  static const Color onNavy = Color(0xFFF1F5FF);
  static const Color onNavyMuted = Color(0xFFB7C6E4);
  static const Color successOnDark = Color(0xFF6EE7A0);
  static const Color warningOnDark = Color(0xFFF8B84A);
}
