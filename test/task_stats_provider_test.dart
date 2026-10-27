import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

void main() {
  test('task stats count pending, done, and due-today tasks', () async {
    final today = DateTime.now();
    final tasks = [
      _task('today', dueAt: today.millisecondsSinceEpoch),
      _task(
        'tomorrow',
        dueAt: today.add(const Duration(days: 1)).millisecondsSinceEpoch,
      ),
      _task('done', dueAt: today.millisecondsSinceEpoch, isDone: true),
    ];
    final container = ProviderContainer(
      overrides: [tasksProvider.overrideWith((ref) async => tasks)],
    );
    addTearDown(container.dispose);

    await container.read(tasksProvider.future);

    expect(container.read(taskStatsProvider), (today: 1, pending: 2, done: 1));
  });
}

Task _task(String id, {int? dueAt, bool isDone = false}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Task(
    id: id,
    title: id,
    priority: 1,
    dueAt: dueAt,
    isDone: isDone,
    createdAt: now,
    updatedAt: now,
    sortIndex: now.toDouble(),
  );
}
