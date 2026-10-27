import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/export/export_service.dart';
import 'package:todo/features/export/ui/export_sheet.dart';
import 'package:todo/features/tasks/data/activity_dao.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';
import 'package:todo/features/tasks/domain/category.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

void main() {
  testWidgets('export sheet forwards category, action, and appendix filters', (
    tester,
  ) async {
    final service = _RecordingExportService(File('/tmp/report.pdf'));
    const categories = [
      Category(id: 'work', name: 'Work', colorValue: 0),
      Category(id: 'personal', name: 'Personal', colorValue: 0),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityDaoProvider.overrideWithValue(_EmptyActivityDao()),
          categoriesProvider.overrideWith((ref) async => categories),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<File>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => ExportSheet(service: service),
                ),
                child: const Text('Open export'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open export'));
    await _pumpAnimations(tester);
    await _pumpAnimations(tester);
    expect(find.text('0 activities across 0 tasks'), findsOneWidget);

    await tester.tap(find.text('Categories'));
    await _pumpAnimations(tester);
    await tester.tap(find.byKey(const ValueKey('export-category-work')));
    await _pumpAnimations(tester);

    await tester.tap(find.text('Actions'));
    await _pumpAnimations(tester);
    final completedAction = find.byKey(
      ValueKey('export-action-${ActivityAction.completed.value}'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await _pumpAnimations(tester);
    await tester.tap(completedAction);
    await _pumpAnimations(tester);
    final appendixToggle = find.byKey(const ValueKey('export-task-appendix'));
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await _pumpAnimations(tester);
    await tester.tap(appendixToggle);
    await _pumpAnimations(tester);

    await tester.tap(find.text('Export PDF'));
    await _pumpAnimations(tester);

    expect(
      service.categoryNames,
      containsAll(['personal', 'Personal', 'Uncategorized']),
    );
    expect(service.categoryNames, isNot(contains('work')));
    expect(
      service.actionValues,
      isNot(contains(ActivityAction.completed.value)),
    );
    expect(service.actionValues, contains(ActivityAction.created.value));
    expect(service.includeTaskAppendix, isTrue);
  });
}

class _EmptyActivityDao extends ActivityDao {
  @override
  Future<List<ActivityEntry>> getInRange({
    required int startAtInclusive,
    required int endAtExclusive,
    int? limit,
  }) async => const [];
}

Future<void> _pumpAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _RecordingExportService extends ExportService {
  _RecordingExportService(this.file);

  final File file;
  Set<String>? categoryNames;
  Set<int>? actionValues;
  bool? includeTaskAppendix;

  @override
  Future<File> exportReport({
    required String appName,
    required DateTime startDate,
    required DateTime endDate,
    bool includeTaskAppendix = false,
    Set<String>? categoryNames,
    Set<int>? actionValues,
  }) async {
    this.categoryNames = categoryNames;
    this.actionValues = actionValues;
    this.includeTaskAppendix = includeTaskAppendix;
    return file;
  }
}
