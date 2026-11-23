import 'package:flutter/material.dart';

/// Brand colors. The Material 3 schemes are generated from these in vega_scheme.dart.
class VegaColors {
  // VEGA Rajasthani Heritage Deep Navy & Electric Blue Palette + Gold-Leaf (#C5A059)
  static const Color deepCanvas = Color(0xFF06132B);
  static const Color deepNavy = Color(0xFF0A1F44);
  static const Color cardMidnight = Color(0xFF0B2552);
  static const Color borderMidnight = Color(0xFF1E3A6B);
  static const Color midnightBlue = Color(0xFF003366);
  // Saffron-orange is the accent of the Vega web design. The old names below
  // (electricBlue, vibrantOrange) now point to it so every screen follows the design.
  static const Color saffron = Color(0xFFD96B08);
  static const Color saffronLight = Color(0xFFE06D06);
  static const Color saffronDeep = Color(0xFFC85A00);
  static const Color saffronDark = Color(0xFFB84E00);
  static const Color saffronShade = Color(0xFF9E4100);
  static const Color goldBorder = Color(0xFFF5D08A);
  static const Color goldPale = Color(0xFFFFE7BA);
  static const Color ivory = Color(0xFFFFFDF8);
  static const Color ivorySand = Color(0xFFF7F1E2);
  static const Color ivoryDeep = Color(0xFFEDE2C8);
  static const Color parchment = Color(0xFFFAF6EC);
  static const Color cream = Color(0xFFFFF5E6);
  static const Color brownText = Color(0xFF6B5A3E);
  static const Color brownMuted = Color(0xFF7A633C);
  static const Color electricBlue = saffron;
  static const Color vibrantOrange = saffron;
  static const Color skyAccent = Color(0xFFC5A059); // Gold-Leaf Accent
  static const Color lightSky = Color(0xFFDBEAFE);
  static const Color skyText = Color(0xFF93C5FD);

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

  /// Main button color (saffron-deep, white text reaches 4.6:1).
  static const Color actionBlue = saffronDeep;

  /// Readable text/icon tones on the dark navy surfaces (all above 4.5:1).
  static const Color onNavy = Color(0xFFF1F5FF);
  static const Color onNavyMuted = Color(0xFFB7C6E4);
  static const Color successOnDark = Color(0xFF6EE7A0);
  static const Color warningOnDark = Color(0xFFF8B84A);
}
