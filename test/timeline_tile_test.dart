import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/activity/ui/widgets/timeline_tile.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

void main() {
  testWidgets('timeline renders every activity action and value changes', (
    tester,
  ) async {
    final labels = [
      'Created',
      'Title edited',
      'Notes edited',
      'Due date changed',
      'Priority changed',
      'Category changed',
      'Completed',
      'Reopened',
      'Subtask added',
      'Subtask completed',
      'Subtask deleted',
      'Reminder set',
      'Reminder cleared',
      'Deleted',
      'Restored',
    ];
    final entries = ActivityAction.values.indexed.map((item) {
      final (index, action) = item;
      return ActivityEntry(
        id: index + 1,
        taskTitle: 'Example task',
        action: action.value,
        field: action == ActivityAction.titleEdited ? 'title' : null,
        oldValue: action == ActivityAction.titleEdited ? 'Old title' : null,
        newValue: action == ActivityAction.titleEdited ? 'New title' : null,
        occurredAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final entry in entries) TimelineTile(entry: entry),
              ],
            ),
          ),
        ),
      ),
    );

    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Old title → New title'), findsOneWidget);
  });
}
