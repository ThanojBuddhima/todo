import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/data/subtask_dao.dart';
import 'package:todo/features/tasks/domain/subtask.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
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
