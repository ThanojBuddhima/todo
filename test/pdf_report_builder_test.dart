import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:todo/features/export/pdf_report_builder.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    final bytes = await _buildPdf(
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

  test('builds a valid PDF for an empty activity range', () async {
    final bytes = await _buildPdf(
      appName: 'Todo',
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2026, 1, 31),
      activities: const [],
    );

    expect(bytes.length, greaterThan(100));
    expect(bytes.sublist(0, 5), [37, 80, 68, 70, 45]);
  });

  test(
    'builds a multipage activity table and optional task appendix',
    () async {
      final activities = List.generate(
        80,
        (index) => ActivityEntry(
          id: index + 1,
          taskId: 'task-${index % 4}',
          taskTitle: 'Example task ${index % 4}',
          categoryName: index.isEven ? 'Work' : null,
          action: ActivityAction.created.value,
          occurredAt: DateTime(
            2026,
            1,
            1,
            8,
          ).add(Duration(minutes: index)).millisecondsSinceEpoch,
        ),
      );

      final bytes = await _buildPdf(
        appName: 'Todo',
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 31),
        generatedAt: DateTime(2026, 2, 1, 12),
        activities: activities,
        includeTaskAppendix: true,
      );

      expect(bytes.length, greaterThan(1000));
      expect(bytes.sublist(0, 5), [37, 80, 68, 70, 45]);
    },
  );

  test('builds a valid PDF for a 1000-entry activity log', () async {
    final activities = List.generate(
      1000,
      (index) => ActivityEntry(
        id: index + 1,
        taskId: 'task-${index % 40}',
        taskTitle: 'Task ${index % 40}',
        categoryName: index.isEven ? 'Work' : 'Personal',
        action:
            ActivityAction.values[index % ActivityAction.values.length].value,
        occurredAt: DateTime(
          2026,
          1,
          1,
        ).add(Duration(minutes: index)).millisecondsSinceEpoch,
      ),
    );

    final bytes = await _buildPdf(
      appName: 'Todo',
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2026, 1, 31),
      activities: activities,
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 5), [37, 80, 68, 70, 45]);
  });

  test('renders non-Latin task text with the embedded Inter fonts', () async {
    final bytes = await _buildPdf(
      appName: 'Todo',
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2026, 1, 31),
      activities: const [
        ActivityEntry(
          id: 1,
          taskTitle: 'Καλημέρα κόσμε',
          action: 0,
          occurredAt: 1767225600000,
        ),
      ],
    );

    expect(bytes.sublist(0, 5), [37, 80, 68, 70, 45]);
  });
}

Future<Uint8List> _buildPdf({
  required String appName,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required List<ActivityEntry> activities,
  DateTime? generatedAt,
  bool includeTaskAppendix = false,
}) async {
  final regularFont = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
  final semiboldFont = await rootBundle.load('assets/fonts/Inter-SemiBold.ttf');
  return const PdfReportBuilder().build(
    appName: appName,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    activities: activities,
    generatedAt: generatedAt,
    includeTaskAppendix: includeTaskAppendix,
    regularFontBytes: regularFont.buffer.asUint8List(
      regularFont.offsetInBytes,
      regularFont.lengthInBytes,
    ),
    semiboldFontBytes: semiboldFont.buffer.asUint8List(
      semiboldFont.offsetInBytes,
      semiboldFont.lengthInBytes,
    ),
  );
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
