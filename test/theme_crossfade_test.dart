import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/core/theme/motion.dart';

/// Pumps a MaterialApp configured exactly the way [App] configures it, so the
/// cross-fade these tests measure is the one the real app runs.
Future<void Function(ThemeMode)> _pumpThemedApp(
  WidgetTester tester,
  void Function(Color background) observe,
) async {
  var mode = ThemeMode.light;
  late StateSetter setOuter;

  await tester.pumpWidget(
    StatefulBuilder(
      builder: (context, setState) {
        setOuter = setState;
        return MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          themeAnimationDuration: AppMotion.themeCrossFade,
          themeAnimationCurve: AppMotion.emphasized,
          home: Builder(
            builder: (inner) {
              observe(Theme.of(inner).scaffoldBackgroundColor);
              return const SizedBox.shrink();
            },
          ),
        );
      },
    ),
  );

  return (next) => setOuter(() => mode = next);
}

void main() {
  final light = AppTheme.light().scaffoldBackgroundColor;
  final dark = AppTheme.dark().scaffoldBackgroundColor;

  testWidgets('light and dark backgrounds are actually different', (_) async {
    expect(light, isNot(dark));
  });

  testWidgets('toggling to dark cross-fades through intermediate colours',
      (tester) async {
    late Color background;
    final setMode = await _pumpThemedApp(tester, (c) => background = c);

    expect(background, light);

    setMode(ThemeMode.dark);
    await tester.pump();
    expect(background, light, reason: 'cross-fade starts at the old theme');

    // Part-way through the 300ms fade the background must be a blend, proving
    // the themes interpolate rather than snap on the next frame.
    await tester.pump(const Duration(milliseconds: 60));
    expect(background, isNot(light));
    expect(background, isNot(dark));

    await tester.pumpAndSettle();
    expect(background, dark, reason: 'cross-fade lands on the new theme');
  });

  testWidgets('cross-fade completes within the documented duration',
      (tester) async {
    late Color background;
    final setMode = await _pumpThemedApp(tester, (c) => background = c);

    setMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(AppMotion.themeCrossFade);
    expect(background, dark);
  });

  testWidgets('fading back to light returns to the original colour',
      (tester) async {
    late Color background;
    final setMode = await _pumpThemedApp(tester, (c) => background = c);

    setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(background, dark);

    setMode(ThemeMode.light);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(background, isNot(dark));

    await tester.pumpAndSettle();
    expect(background, light);
  });
}
