import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/core/theme/app_theme.dart';

double _channel(double value) =>
    value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b);

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA contrast', () {
    test('contrastRatio matches known reference values', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.01));
    });

    for (final entry in {
      'light': (theme: AppTheme.light(), card: AppColors.lightCard),
      'dark': (theme: AppTheme.dark(), card: AppColors.darkCard),
    }.entries) {
      final name = entry.key;
      final theme = entry.value.theme;
      final card = entry.value.card;
      final scheme = theme.colorScheme;
      final text = theme.textTheme;

      test('$name body text clears 4.5:1 on surface and card', () {
        final body = text.bodyMedium!.color!;
        expect(contrastRatio(body, scheme.surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(body, card), greaterThanOrEqualTo(4.5));
      });

      test('$name muted text clears 4.5:1 on surface and card', () {
        final muted = text.bodySmall!.color!;
        expect(muted, scheme.onSurfaceVariant);
        expect(contrastRatio(muted, scheme.surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(muted, card), greaterThanOrEqualTo(4.5));
      });

      test('$name priority labels clear 4.5:1 on their soft pill fill', () {
        final brightness = theme.brightness;
        for (final base in [
          AppColors.lowPriority,
          AppColors.mediumPriority,
          AppColors.highPriority,
        ]) {
          final fill = AppColors.soft(base, brightness);
          final label = AppColors.onSoft(base, brightness);
          expect(
            contrastRatio(label, fill),
            greaterThanOrEqualTo(4.5),
            reason: '$name pill for $base',
          );
        }
      });
    }
  });
}
