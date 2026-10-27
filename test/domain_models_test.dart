import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';
import 'package:todo/features/tasks/domain/category.dart';
import 'package:todo/features/tasks/domain/priority.dart';
import 'package:todo/features/tasks/domain/subtask.dart';
import 'package:todo/features/tasks/domain/task.dart';

void main() {
  test('priority values remain aligned with the persisted integer values', () {
    expect(Priority.low.value, 0);
    expect(Priority.medium.value, 1);
    expect(Priority.high.value, 2);
    expect(Priority.fromValue(0), Priority.low);
    expect(Priority.fromValue(1), Priority.medium);
    expect(Priority.fromValue(2), Priority.high);
    expect(Priority.fromValue(99), Priority.medium);
  });

  test('task maps preserve priority and nullable fields', () {
    const task = Task(
      id: 'task-1',
      title: 'Review report',
      notes: 'Check the final numbers',
      categoryId: 'work',
      priority: Priority.high,
      dueAt: 100,
      remindAt: 90,
      notificationId: 7,
      isDone: true,
      completedAt: 110,
      createdAt: 10,
      updatedAt: 120,
      sortIndex: 1.5,
      deletedAt: 130,
    );

    final map = task.toMap();
    expect(map['priority'], 2);
    expect(Task.fromMap(map).toMap(), map);
  });

  test('subtask and category maps round-trip', () {
    const subtask = Subtask(
      id: 'subtask-1',
      taskId: 'task-1',
      title: 'Check citations',
      isDone: true,
      sortIndex: 2.5,
      createdAt: 10,
    );
    const category = Category(
      id: 'work',
      name: 'Work',
      colorValue: 0xFF3B82F6,
      iconCode: 42,
    );

    expect(Subtask.fromMap(subtask.toMap()).toMap(), subtask.toMap());
    expect(Category.fromMap(category.toMap()).toMap(), category.toMap());
  });

  test('activity entries map to and from database columns', () {
    const entry = ActivityEntry(
      id: 4,
      taskId: 'task-1',
      taskTitle: 'Review report',
      categoryName: 'Work',
      action: 2,
      field: 'notes',
      oldValue: null,
      newValue: 'Check the final numbers',
      occurredAt: 120,
    );

    expect(ActivityEntry.fromMap(entry.toMap()).toMap(), entry.toMap());
  });
}
