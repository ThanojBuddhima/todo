import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Flat, near-white light surfaces and a true-dark counterpart. Depth comes
/// from hairline borders rather than shadows, so cards stay crisp in both themes.
class AppColors {
  const AppColors._();

  static const seed = Color(0xFF6C5CE7);

  static const lightBackground = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightContainer = Color(0xFFF5F6F8);
  static const lightBorder = Color(0xFFECEDF1);
  static const lightText = Color(0xFF14141A);
  static const lightTextMuted = Color(0xFF6B6B78);

  static const darkBackground = Color(0xFF0E0E13);
  static const darkCard = Color(0xFF17171F);
  static const darkContainer = Color(0xFF1E1E28);
  static const darkBorder = Color(0xFF2A2A36);
  static const darkText = Color(0xFFF3F3F6);
  static const darkTextMuted = Color(0xFF9A9AA7);

  static const lowPriority = Color(0xFF10B981);
  static const mediumPriority = Color(0xFFF59E0B);
  static const highPriority = Color(0xFFF43F5E);

  static const done = Color(0xFF10B981);
  static const neutral = Color(0xFF8E8E93);
  static const created = Color(0xFF6C5CE7);
  static const edited = Color(0xFF0EA5E9);
  static const deleted = Color(0xFFF43F5E);
  static const restored = Color(0xFF8B5CF6);
  static const reminder = Color(0xFFF59E0B);
  static const subtask = Color(0xFF14B8A6);

  /// Pastel pill fill for [base] — tinted in light, muted in dark.
  static Color soft(Color base, Brightness brightness) => brightness == Brightness.dark
      ? Color.alphaBlend(base.withValues(alpha: 0.20), darkCard)
      : Color.alphaBlend(base.withValues(alpha: 0.12), lightCard);

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
    double channel(double value) =>
        value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
  }
}
