import 'package:flutter/material.dart';
import 'package:todo/core/theme/app_colors.dart';

/// Type scale built on fonts bundled in `assets/fonts/`, never fetched at
/// runtime — the app must render identically with no network.
class AppTypography {
  const AppTypography._();

  static const poppins = 'Poppins';

  /// Still bundled for the PDF report, which embeds the raw font bytes.
  static const inter = 'Inter';
  static const manrope = 'Manrope';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Poppins ships as discrete weight files, so the weight is picked by
  /// [FontWeight] rather than a variable axis.
  static TextStyle _heading(double size, double tracking, double height) =>
      TextStyle(
        fontFamily: poppins,
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: tracking,
        height: height,
      );

  static TextStyle _body(
    double size,
    FontWeight weight,
    double height, [
    double tracking = 0,
  ]) => TextStyle(
    fontFamily: poppins,
    fontWeight: weight,
    fontSize: size,
    height: height,
    letterSpacing: tracking,
  );

  /// Adds tabular figures so dates and counts stay column-aligned.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: _tabular);

  static TextTheme textTheme(Brightness brightness) {
    final primary = brightness == Brightness.dark
        ? AppColors.darkText
        : AppColors.lightText;
    final muted = brightness == Brightness.dark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;

    final theme = TextTheme(
      displayLarge: _heading(38, -0.8, 1.18),
      displayMedium: _heading(32, -0.7, 1.18),
      displaySmall: _heading(28, -0.5, 1.20),
      headlineLarge: _heading(26, -0.4, 1.22),
      headlineMedium: _heading(23, -0.3, 1.24),
      headlineSmall: _heading(20, -0.2, 1.28),
      titleLarge: _heading(18, -0.1, 1.32),
      titleMedium: _body(15.5, FontWeight.w600, 1.38, 0),
      titleSmall: _body(14, FontWeight.w600, 1.35),
      bodyLarge: _body(15.5, FontWeight.w400, 1.52),
      bodyMedium: _body(13.5, FontWeight.w400, 1.48),
      bodySmall: _body(11.5, FontWeight.w400, 1.42),
      labelLarge: _body(13.5, FontWeight.w500, 1.22),
      labelMedium: _body(11.5, FontWeight.w500, 1.22, 0.1),
      labelSmall: _body(10.5, FontWeight.w500, 1.22, 0.4),
    );

    return theme
        .apply(bodyColor: primary, displayColor: primary)
        .copyWith(
          bodySmall: theme.bodySmall?.copyWith(color: muted),
          labelSmall: theme.labelSmall?.copyWith(color: muted),
        );
  }
}
