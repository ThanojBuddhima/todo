import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/home_screen.dart';

void main() {
  testWidgets('groups tasks by due date and collapses the done group', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tasks = [
      _task(
        'overdue',
        'Overdue sample',
        dueAt: today.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      ),
      _task('today', 'Today sample', dueAt: today.millisecondsSinceEpoch),
      _task(
        'tomorrow',
        'Tomorrow sample',
        dueAt: today.add(const Duration(days: 1)).millisecondsSinceEpoch,
      ),
      _task('later', 'Later sample'),
      _task('done', 'Completed sample', isDone: true),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksProvider.overrideWith((ref) async => tasks),
          filteredTasksProvider.overrideWith((ref) async => tasks),
          categoriesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Today'), findsAtLeastNWidgets(2));
    expect(find.text('Tomorrow'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Later'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Completed sample'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Done').last,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();

    expect(find.text('Completed sample'), findsOneWidget);
  });
}

Task _task(String id, String title, {int? dueAt, bool isDone = false}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Task(
    id: id,
    title: title,
    priority: 1,
    dueAt: dueAt,
    isDone: isDone,
    createdAt: now,
    updatedAt: now,
    sortIndex: now.toDouble(),
  );
}
