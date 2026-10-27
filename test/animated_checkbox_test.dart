import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/ui/widgets/animated_checkbox.dart';

void main() {
  testWidgets('animated checkbox toggles and honors reduced motion', (
    tester,
  ) async {
    var checked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: AnimatedCheckbox(
                value: checked,
                onChanged: (value) => setState(() => checked = value),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Complete task'));
    await tester.pump();

    expect(checked, isTrue);
    expect(find.bySemanticsLabel('Mark task as pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
