import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/export/pdf_report_builder.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

void main() {
  test('summarizes task events and finds the busiest day', () {
    final busiestDay = DateTime(2026, 1, 1);
    final summary = PdfReportBuilder.summarize([
      _entry(
        1,
        'task-a',
        ActivityAction.created,
        busiestDay,
        categoryName: 'Work',
      ),
      _entry(
        2,
        'task-a',
        ActivityAction.completed,
        busiestDay.add(const Duration(hours: 1)),
        categoryName: 'Work',
      ),
      _entry(
        3,
        'task-b',
        ActivityAction.created,
        busiestDay.add(const Duration(days: 1)),
        categoryName: 'Personal',
      ),
      _entry(
        4,
        'task-c',
        ActivityAction.deleted,
        busiestDay.add(const Duration(hours: 2)),
      ),
    ]);

    expect(summary.created, 2);
    expect(summary.completed, 1);
    expect(summary.deleted, 1);
    expect(summary.completionRate, 0.5);
    expect(summary.busiestDay, busiestDay);
    expect(summary.categoryActivityCounts, {
      'Work': 2,
      'Personal': 1,
      'Uncategorized': 1,
    });
  });

  test('builds a PDF cover from report data without database access', () async {
    final bytes = await const PdfReportBuilder().build(
      appName: 'Todo',
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2026, 1, 31),
      generatedAt: DateTime(2026, 2, 1, 12),
      activities: const [
        ActivityEntry(
          id: 1,
          taskTitle: 'Example task',
          action: 0,
          occurredAt: 1767225600000,
        ),
      ],
    );

    expect(bytes.length, greaterThan(100));
    expect(bytes.sublist(0, 5), [37, 80, 68, 70, 45]);
  });

  test('builds a multipage activity table and optional task appendix', () async {
    final activities = List.generate(
      80,
      (index) => ActivityEntry(
        id: index + 1,
        taskId: 'task-${index % 4}',
        taskTitle: 'Example task ${index % 4}',
        categoryName: index.isEven ? 'Work' : null,
        action: ActivityAction.created.value,
        occurredAt: DateTime(2026, 1, 1, 8).add(Duration(minutes: index)).millisecondsSinceEpoch,
      ),
    );

    final bytes = await const PdfReportBuilder().build(
      appName: 'Todo',
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2026, 1, 31),
      generatedAt: DateTime(2026, 2, 1, 12),
      activities: activities,
      includeTaskAppendix: true,
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 5), [37, 80, 68, 70, 45]);
  });
}

ActivityEntry _entry(
  int id,
  String taskId,
  ActivityAction action,
  DateTime occurredAt, {
  String? categoryName,
}) {
  return ActivityEntry(
    id: id,
    taskId: taskId,
    taskTitle: taskId,
    categoryName: categoryName,
    action: action.value,
    occurredAt: occurredAt.millisecondsSinceEpoch,
  );
}
