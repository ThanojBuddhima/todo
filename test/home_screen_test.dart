import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/data/task_dao.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/home_screen.dart';
import 'package:todo/features/tasks/ui/task_detail_screen.dart';

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
          for (final task in tasks)
            subtasksProvider(task.id).overrideWith((ref) async => const []),
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

  testWidgets('deleting a task offers undo and restores it', (tester) async {
    final task = _task('delete-me', 'Task to delete');
    final dao = _FakeTaskDao();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDaoProvider.overrideWithValue(dao),
          tasksProvider.overrideWith((ref) async => [task]),
          filteredTasksProvider.overrideWith((ref) async => [task]),
          categoriesProvider.overrideWith((ref) async => []),
          subtasksProvider(task.id).overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Task to delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(dao.deletedTaskId, task.id);
    expect(find.text('Task deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(dao.restoredTaskId, task.id);
  });

  testWidgets('task editor opens in a draggable scrollable sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDaoProvider.overrideWithValue(_FakeTaskDao()),
          tasksProvider.overrideWith((ref) async => []),
          filteredTasksProvider.overrideWith((ref) async => []),
          categoriesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping right reveals complete action', (tester) async {
    final task = _task('swipe-complete', 'Swipe to complete');
    final dao = _FakeTaskDao();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDaoProvider.overrideWithValue(dao),
          tasksProvider.overrideWith((ref) async => [task]),
          filteredTasksProvider.overrideWith((ref) async => [task]),
          categoriesProvider.overrideWith((ref) async => []),
          subtasksProvider(task.id).overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Swipe to complete'), const Offset(450, 0));
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    expect(dao.toggledTaskId, task.id);
  });

  testWidgets('swiping left reveals delete action and undo', (tester) async {
    final task = _task('swipe-delete', 'Swipe to delete');
    final dao = _FakeTaskDao();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDaoProvider.overrideWithValue(dao),
          tasksProvider.overrideWith((ref) async => [task]),
          filteredTasksProvider.overrideWith((ref) async => [task]),
          categoriesProvider.overrideWith((ref) async => []),
          subtasksProvider(task.id).overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Swipe to delete'), const Offset(-450, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(dao.deletedTaskId, task.id);
    expect(find.text('Task deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(dao.restoredTaskId, task.id);
  });

  testWidgets('task card opens detail with a shared-axis transition', (
    tester,
  ) async {
    final task = _task('transition-task', 'Open task detail');
    final dao = _FakeTaskDao();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDaoProvider.overrideWithValue(dao),
          tasksProvider.overrideWith((ref) async => [task]),
          filteredTasksProvider.overrideWith((ref) async => [task]),
          taskByIdProvider(task.id).overrideWith((ref) async => task),
          categoriesProvider.overrideWith((ref) async => []),
          subtasksProvider(task.id).overrideWith((ref) async => const []),
          taskActivityProvider(task.id).overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open task detail'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(find.text('Task details'), findsOneWidget);
  });

  testWidgets('reduced motion skips staggered task entrance animation', (
    tester,
  ) async {
    final tasks = [
      _task('motion-one', 'First motion task'),
      _task('motion-two', 'Second motion task'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksProvider.overrideWith((ref) async => tasks),
          filteredTasksProvider.overrideWith((ref) async => tasks),
          categoriesProvider.overrideWith((ref) async => []),
          for (final task in tasks)
            subtasksProvider(task.id).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First motion task'), findsOneWidget);
    expect(find.text('Second motion task'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

class _FakeTaskDao extends TaskDao {
  String? deletedTaskId;
  String? restoredTaskId;
  String? toggledTaskId;

  @override
  Future<void> toggleDone(String taskId) async {
    toggledTaskId = taskId;
  }

  @override
  Future<void> softDelete(String taskId) async {
    deletedTaskId = taskId;
  }

  @override
  Future<void> restoreTask(String taskId) async {
    restoredTaskId = taskId;
  }
}
