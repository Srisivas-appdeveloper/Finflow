import 'package:flutter/material.dart';

/// Type scale, set entirely in Manrope (bundled; see pubspec.yaml).
///
/// * Headlines are bold with tight tracking.
/// * Large amounts use light weights with tabular figures, so they look
///   crisp on glass and roll cleanly.
abstract final class AppTypography {
  static const sans = 'Manrope';

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: sans,
        fontSize: 56,
        height: 1.0,
        fontWeight: FontWeight.w300,
        letterSpacing: -2.2,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontFamily: sans,
        fontSize: 42,
        height: 1.05,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.4,
        color: primary,
      ),
      displaySmall: TextStyle(
        fontFamily: sans,
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w500,
        letterSpacing: -1,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontFamily: sans,
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: sans,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontFamily: sans,
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: sans,
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontFamily: sans,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontFamily: sans,
        fontSize: 14.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontFamily: sans,
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: sans,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: TextStyle(
        fontFamily: sans,
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontFamily: sans,
        fontSize: 14.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontFamily: sans,
        fontSize: 12.5,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontFamily: sans,
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: secondary,
      ),
    );
  }
}

extension AmountTextStyle on TextStyle {
  /// Fixed-width digits so amounts align in lists and don't jitter while
  /// animating.
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

extension EyebrowText on TextTheme {
  /// Small, widely tracked label used above headings ("NET · OCTOBER").
  /// Pass text in upper case.
  TextStyle get eyebrow => labelSmall!.copyWith(letterSpacing: 1.4);

  /// Large bold greeting on the home screen.
  TextStyle get greeting => headlineLarge!;
}
