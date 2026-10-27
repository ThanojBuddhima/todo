import 'package:flutter/material.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/core/theme/app_typography.dart';

class AppTheme {
  const AppTheme._();

  static const double cardRadius = 20;
  static const double controlRadius = 14;
  static const double pillRadius = 100;

  static ThemeData light({Color? seed}) => _build(
        brightness: Brightness.light,
        seed: seed ?? AppColors.seed,
        background: AppColors.lightBackground,
        card: AppColors.lightCard,
        container: AppColors.lightContainer,
        border: AppColors.lightBorder,
        text: AppColors.lightText,
        muted: AppColors.lightTextMuted,
      );

  static ThemeData dark({Color? seed}) => _build(
        brightness: Brightness.dark,
        seed: seed ?? AppColors.seed,
        background: AppColors.darkBackground,
        card: AppColors.darkCard,
        container: AppColors.darkContainer,
        border: AppColors.darkBorder,
        text: AppColors.darkText,
        muted: AppColors.darkTextMuted,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color background,
    required Color card,
    required Color container,
    required Color border,
    required Color text,
    required Color muted,
  }) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final scheme = base.copyWith(
      surface: background,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: container,
      surfaceContainerHigh: container,
      surfaceContainerHighest: container,
      outline: border,
      outlineVariant: border,
    );
    final textTheme = AppTypography.textTheme(brightness);
    final hairline = BorderSide(color: border, width: 1);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: hairline,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: container,
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: container,
        selectedColor: AppColors.soft(scheme.primary, brightness),
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.soft(scheme.primary, brightness),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium?.copyWith(color: scheme.primary)
              : textTheme.labelMedium?.copyWith(color: muted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? scheme.primary : muted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark ? AppColors.darkContainer : AppColors.lightText,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.dark ? AppColors.darkText : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: container,
          selectedBackgroundColor: AppColors.soft(scheme.primary, brightness),
          selectedForegroundColor: scheme.primary,
          foregroundColor: muted,
          side: BorderSide.none,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
    );
  }
}
