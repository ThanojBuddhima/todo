import 'package:flutter/material.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/core/theme/app_typography.dart';

class AppTheme {
  static ThemeData light({Color? seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? AppColors.seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
      textTheme: AppTypography.textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
      ),
    );
  }

  static ThemeData dark({Color? seed}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? AppColors.seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkCard,
      textTheme: AppTypography.textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: AppColors.darkCard,
      ),
    );
  }
}
