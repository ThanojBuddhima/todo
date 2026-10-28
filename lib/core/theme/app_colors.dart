import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Neutral surfaces: white in light, true black in dark, with no hue in the
/// greys. Colour comes from the accent and the status pills, never the canvas.
/// Depth is carried by hairline borders rather than shadows, so a white card on
/// a white page still reads as a card.
class AppColors {
  const AppColors._();

  static const seed = Color(0xFF3B82F6);

  static const lightBackground = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightContainer = Color(0xFFF4F4F5);
  static const lightBorder = Color(0xFFE6E6E8);
  static const lightText = Color(0xFF131316);
  static const lightTextMuted = Color(0xFF6A6A72);

  static const darkBackground = Color(0xFF000000);
  static const darkCard = Color(0xFF131315);
  static const darkContainer = Color(0xFF1C1C1F);
  static const darkBorder = Color(0xFF2A2A2E);
  static const darkText = Color(0xFFF4F4F5);
  static const darkTextMuted = Color(0xFF9B9BA3);

  static const lowPriority = Color(0xFF12B981);
  static const mediumPriority = Color(0xFFF99B07);
  static const highPriority = Color(0xFFFB4D64);

  static const done = Color(0xFF12B981);
  static const neutral = Color(0xFF8A94A6);
  static const created = Color(0xFF3B82F6);
  static const edited = Color(0xFF06B6D4);
  static const deleted = Color(0xFFFB4D64);
  static const restored = Color(0xFF8B5CF6);
  static const reminder = Color(0xFFF99B07);
  static const subtask = Color(0xFF14B8A6);

  /// Pastel pill fill for [base] — tinted in light, muted in dark. Carries a
  /// little more hue than a plain tint so pills read as colour, not grey.
  static Color soft(Color base, Brightness brightness) =>
      brightness == Brightness.dark
      ? Color.alphaBlend(base.withValues(alpha: 0.24), darkCard)
      : Color.alphaBlend(base.withValues(alpha: 0.16), lightCard);

  /// Card wash for [base] — lighter than [soft], because it sits under body
  /// text rather than behind a short pill label.
  static Color surfaceTint(Color base, Brightness brightness) =>
      brightness == Brightness.dark
          ? Color.alphaBlend(base.withValues(alpha: 0.14), darkCard)
          : Color.alphaBlend(base.withValues(alpha: 0.09), lightCard);

  /// Label colour on top of [soft]. Walks [base] away from the fill until it
  /// clears WCAG AA, so light hues like amber stay readable in their own pill.
  static Color onSoft(Color base, Brightness brightness) {
    final fill = soft(base, brightness);
    final step = brightness == Brightness.dark ? 0.02 : -0.02;
    var hsl = HSLColor.fromColor(base);
    for (var i = 0; i < 50; i++) {
      final candidate = hsl.toColor();
      if (_contrast(candidate, fill) >= 4.5) return candidate;
      hsl = hsl.withLightness((hsl.lightness + step).clamp(0.0, 1.0));
    }
    return hsl.toColor();
  }

  static double _contrast(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static double _relativeLuminance(Color color) {
    double channel(double value) => value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }
}
