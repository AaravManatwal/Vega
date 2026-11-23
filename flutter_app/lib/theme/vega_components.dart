import 'package:flutter/material.dart';
import 'vega_colors.dart';

/// Material 3 component themes, built from a ColorScheme so light, dark and any
/// future (dynamic) scheme share one definition.
class VegaComponents {
  static const double _cardRadius = 20;
  static const double _controlRadius = 16;

  static TextTheme textTheme(TextTheme base) {
    return base.copyWith(
      // Display text uses the serif face, like the web design's heritage headings.
      displaySmall: base.displaySmall?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  static ThemeData apply(ThemeData base, ColorScheme cs, {required bool dark}) {
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_controlRadius),
    );
    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor:
          dark ? VegaColors.deepNavy : VegaColors.lightBackground,
      textTheme: textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? VegaColors.deepCanvas : VegaColors.deepNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: dark ? VegaColors.deepNavy : VegaColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(
            color: VegaColors.sandstoneGold.withValues(alpha: dark ? 0.35 : 0.40),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Finite minimum width: a full-width minimum breaks buttons inside a Row.
          minimumSize: const Size(64, 56),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: controlShape,
          side: BorderSide(color: cs.outline),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: controlShape,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: cs.outlineVariant),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainer,
        indicatorColor: cs.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
        circularTrackColor: cs.surfaceContainerHighest,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
