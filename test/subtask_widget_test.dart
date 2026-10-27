import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/data/subtask_dao.dart';
import 'package:todo/features/tasks/data/task_dao.dart';
import 'package:todo/features/tasks/domain/subtask.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/home_screen.dart';
import 'package:todo/features/tasks/ui/widgets/task_subtasks_section.dart';

void main() {
  testWidgets('subtasks can be added, completed, renamed, and removed', (
    tester,
  ) async {
    final dao = _FakeSubtaskDao();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subtaskDaoProvider.overrideWithValue(dao),
          subtasksProvider('task').overrideWith((ref) async => dao.items),
          tasksProvider.overrideWith((ref) async => []),
          taskActivityProvider('task').overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: Scaffold(body: TaskSubtasksSection(taskId: 'task')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Add a subtask',
      ),
      'Prepare notes',
    );
    await tester.tap(find.byTooltip('Add subtask'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare notes'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(dao.items.single.isDone, isTrue);
    expect(find.text('1/1'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename subtask'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Review notes');
    await tester.tap(find.byTooltip('Save subtask'));
    await tester.pumpAndSettle();
    expect(find.text('Review notes'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete subtask'));
    await tester.pumpAndSettle();
    expect(dao.items, isEmpty);
    expect(find.text('0/0'), findsOneWidget);
  });

  testWidgets('completing a subtask updates progress on detail and task card', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = Task(
      id: 'task-progress',
      title: 'Progress sample',
      priority: 1,
      isDone: false,
      createdAt: now,
      updatedAt: now,
      sortIndex: now.toDouble(),
    );
    final dao = _FakeSubtaskDao()
      ..items.addAll([
        _subtask('first', task.id, 'First', isDone: true),
        _subtask('second', task.id, 'Second'),
      ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDaoProvider.overrideWithValue(_FakeTaskDao(task)),
          subtaskDaoProvider.overrideWithValue(dao),
          tasksProvider.overrideWith((ref) async => [task]),
          filteredTasksProvider.overrideWith((ref) async => [task]),
          taskByIdProvider(task.id).overrideWith((ref) async => task),
          subtasksProvider(
            task.id,
          ).overrideWith((ref) => dao.getForTask(task.id)),
          taskActivityProvider(task.id).overrideWith((ref) async => const []),
          categoriesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1/2 subtasks'), findsOneWidget);

    await tester.tap(find.text('Progress sample').first);
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('2/2 subtasks'), findsOneWidget);
  });
}

class _FakeSubtaskDao extends SubtaskDao {
  final List<Subtask> items = [];
  int _nextId = 0;

  @override
  Future<List<Subtask>> getForTask(String taskId) async => items;

  @override
  Future<void> addSubtask(String taskId, String title) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    items.add(
      Subtask(
        id: 'subtask-${_nextId++}',
        taskId: taskId,
        title: title,
        isDone: false,
        sortIndex: items.length.toDouble(),
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> toggleSubtask(String subtaskId, bool isDone) async {
    final index = items.indexWhere((subtask) => subtask.id == subtaskId);
    items[index] = _copy(items[index], isDone: isDone);
  }

  @override
  Future<void> renameSubtask(String subtaskId, String title) async {
    final index = items.indexWhere((subtask) => subtask.id == subtaskId);
    items[index] = _copy(items[index], title: title);
  }

  @override
  Future<void> deleteSubtask(String subtaskId) async {
    items.removeWhere((subtask) => subtask.id == subtaskId);
  }

  @override
  Future<void> reorderSubtasks(String taskId, List<String> orderedIds) async {
    final ordered = [
      for (final id in orderedIds)
        items.firstWhere((subtask) => subtask.id == id),
    ];
    items
      ..clear()
      ..addAll(ordered);
  }

  Subtask _copy(Subtask subtask, {String? title, bool? isDone}) => Subtask(
    id: subtask.id,
    taskId: subtask.taskId,
    title: title ?? subtask.title,
    isDone: isDone ?? subtask.isDone,
    sortIndex: subtask.sortIndex,
    createdAt: subtask.createdAt,
  );
}

Subtask _subtask(
  String id,
  String taskId,
  String title, {
  bool isDone = false,
}) {
  return Subtask(
    id: id,
    taskId: taskId,
    title: title,
    isDone: isDone,
    sortIndex: 0,
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
}

class _FakeTaskDao extends TaskDao {
  _FakeTaskDao(this.task);

  final Task task;

  @override
  Future<Task?> getTaskById(String id) async => id == task.id ? task : null;
}
