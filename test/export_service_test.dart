import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/export/export_service.dart';
import 'package:todo/features/export/pdf_report_builder.dart';
import 'package:todo/features/tasks/data/activity_dao.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

void main() {
  test('queries the selected days and writes a timestamped PDF', () async {
    final directory = await Directory.systemTemp.createTemp('todo-export-');
    addTearDown(() => directory.delete(recursive: true));
    final dao = _FakeActivityDao();
    final builder = _FakePdfReportBuilder();
    final generatedAt = DateTime(2026, 3, 8, 9, 7);
    final service = ExportService(
      activityDao: dao,
      reportBuilder: builder,
      documentsDirectory: () async => directory,
      clock: () => generatedAt,
    );

    final file = await service.exportReport(
      appName: 'Todo',
      startDate: DateTime(2026, 1, 1, 14),
      endDate: DateTime(2026, 1, 2, 20),
      includeTaskAppendix: true,
    );

    expect(dao.requestedRange, (
      startAtInclusive: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      endAtExclusive: DateTime(2026, 1, 3).millisecondsSinceEpoch,
    ));
    expect(builder.rangeStart, DateTime(2026, 1, 1));
    expect(builder.rangeEnd, DateTime(2026, 1, 2));
    expect(builder.includeTaskAppendix, isTrue);
    expect(file.path, endsWith('activity-report-20260308-0907.pdf'));
    expect(await file.readAsBytes(), [37, 80, 68, 70, 45]);
  });

  test('filters the report by category and action', () async {
    final directory = await Directory.systemTemp.createTemp('todo-export-');
    addTearDown(() => directory.delete(recursive: true));
    final dao = _FakeActivityDao([
      _entry(1, ActivityAction.created, 'Work'),
      _entry(2, ActivityAction.deleted, 'Personal'),
      _entry(3, ActivityAction.completed, null),
    ]);
    final builder = _FakePdfReportBuilder();
    final service = ExportService(
      activityDao: dao,
      reportBuilder: builder,
      documentsDirectory: () async => directory,
      clock: () => DateTime(2026, 3, 8),
    );

    await service.exportReport(
      appName: 'Todo',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 2),
      categoryNames: {'Personal', 'Uncategorized'},
      actionValues: {
        ActivityAction.deleted.value,
        ActivityAction.completed.value,
      },
    );

    expect(builder.activities.map((entry) => entry.id), [2, 3]);
  });
}

class _FakeActivityDao extends ActivityDao {
  _FakeActivityDao([this.entries = const []]);

  ({int startAtInclusive, int endAtExclusive})? requestedRange;
  final List<ActivityEntry> entries;

  @override
  Future<List<ActivityEntry>> getInRange({
    required int startAtInclusive,
    required int endAtExclusive,
    int? limit,
  }) async {
    requestedRange = (
      startAtInclusive: startAtInclusive,
      endAtExclusive: endAtExclusive,
    );
    return entries;
  }
}

class _FakePdfReportBuilder extends PdfReportBuilder {
  DateTime? rangeStart;
  DateTime? rangeEnd;
  bool? includeTaskAppendix;
  List<ActivityEntry> activities = [];

  @override
  Future<Uint8List> build({
    required String appName,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<ActivityEntry> activities,
    DateTime? generatedAt,
    bool includeTaskAppendix = false,
  }) async {
    this.rangeStart = rangeStart;
    this.rangeEnd = rangeEnd;
    this.includeTaskAppendix = includeTaskAppendix;
    this.activities = activities;
    return Uint8List.fromList([37, 80, 68, 70, 45]);
  }
}

ActivityEntry _entry(int id, ActivityAction action, String? categoryName) {
  return ActivityEntry(
    id: id,
    taskTitle: 'Task $id',
    categoryName: categoryName,
    action: action.value,
    occurredAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
  );
}
