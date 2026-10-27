import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/activity/ui/history_screen.dart';
import 'package:todo/features/tasks/data/activity_dao.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

void main() {
  testWidgets('history groups entries and filters by action type', (
    tester,
  ) async {
    final now = DateTime.now();
    final dao = _FakeActivityDao([
      ActivityEntry(
        id: 1,
        taskTitle: 'Created task',
        action: ActivityAction.created.value,
        occurredAt: now.millisecondsSinceEpoch,
      ),
      ActivityEntry(
        id: 2,
        taskTitle: 'Deleted task',
        action: ActivityAction.deleted.value,
        occurredAt: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [activityDaoProvider.overrideWithValue(dao)],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Created task'), findsOneWidget);
    expect(find.text('Deleted task'), findsOneWidget);
    expect(find.text('All dates'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(
        ValueKey('history-action-filter-${ActivityAction.deleted.value}'),
      ),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(
        ValueKey('history-action-filter-${ActivityAction.deleted.value}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Created task'), findsNothing);
    expect(find.text('Deleted task'), findsOneWidget);
  });
}

class _FakeActivityDao extends ActivityDao {
  _FakeActivityDao(this.entries);

  final List<ActivityEntry> entries;

  @override
  Future<List<ActivityEntry>> getInRange({
    required int startAtInclusive,
    required int endAtExclusive,
    int? limit,
  }) async => entries;
}
