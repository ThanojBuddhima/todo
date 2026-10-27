import 'package:flutter/material.dart';
import 'package:todo/core/theme/app_colors.dart';

/// Type scale built on fonts bundled in `assets/fonts/`, never fetched at
/// runtime — the app must render identically with no network.
class AppTypography {
  const AppTypography._();

  static const inter = 'Inter';
  static const manrope = 'Manrope';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Manrope ships as a variable font, so weight is set through the `wght`
  /// axis. Passing [fontWeight] as well would trigger synthetic bolding.
  static TextStyle _heading(double size, double tracking, double height) => TextStyle(
        fontFamily: manrope,
        fontVariations: const [FontVariation('wght', 700)],
        fontSize: size,
        letterSpacing: tracking,
        height: height,
      );

  static TextStyle _body(double size, FontWeight weight, double height, [double tracking = 0]) =>
      TextStyle(
        fontFamily: inter,
        fontWeight: weight,
        fontSize: size,
        height: height,
        letterSpacing: tracking,
      );

  /// Adds tabular figures so dates and counts stay column-aligned.
  static TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: _tabular);

  static TextTheme textTheme(Brightness brightness) {
    final primary = brightness == Brightness.dark ? AppColors.darkText : AppColors.lightText;
    final muted = brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final theme = TextTheme(
      displayLarge: _heading(40, -1.2, 1.15),
      displayMedium: _heading(34, -1.0, 1.15),
      displaySmall: _heading(30, -0.8, 1.18),
      headlineLarge: _heading(28, -0.7, 1.20),
      headlineMedium: _heading(24, -0.6, 1.22),
      headlineSmall: _heading(21, -0.4, 1.25),
      titleLarge: _heading(18, -0.3, 1.30),
      titleMedium: _body(16, FontWeight.w600, 1.35, -0.1),
      titleSmall: _body(14, FontWeight.w600, 1.35),
      bodyLarge: _body(16, FontWeight.w400, 1.50),
      bodyMedium: _body(14, FontWeight.w400, 1.45),
      bodySmall: _body(12, FontWeight.w400, 1.40),
      labelLarge: _body(14, FontWeight.w600, 1.20),
      labelMedium: _body(12, FontWeight.w600, 1.20, 0.1),
      labelSmall: _body(11, FontWeight.w600, 1.20, 0.6),
    );

    return theme.apply(bodyColor: primary, displayColor: primary).copyWith(
          bodySmall: theme.bodySmall?.copyWith(color: muted),
          labelSmall: theme.labelSmall?.copyWith(color: muted),
        );
  }
}
