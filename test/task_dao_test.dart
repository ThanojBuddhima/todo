import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todo/core/db/app_database.dart';
import 'package:todo/features/tasks/data/task_dao.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/priority.dart';
import 'package:todo/features/tasks/domain/task.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await AppDatabase.instance.database;
    await db.delete('activity_log');
    await db.delete('subtasks');
    await db.delete('tasks');
  });

  test('createTask writes a created activity entry', () async {
    final dao = TaskDao();
    final taskId = await dao.createTask(
      title: 'Write tests',
      notes: 'Keep them green',
      categoryId: 'work',
      priority: Priority.medium,
    );

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'activity_log',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );

    expect(rows, hasLength(1));
    expect(rows.single['action'], ActivityAction.created.value);
    expect(rows.single['task_title'], 'Write tests');
  });

  test('updateTask writes field-specific activity entries', () async {
    final db = await AppDatabase.instance.database;
    final dao = TaskDao();
    final taskId = await dao.createTask(
      title: 'Plan release',
      categoryId: 'personal',
    );

    final task = await dao.getTaskById(taskId);
    expect(task, isNotNull);

    final updated = Task(
      id: task!.id,
      title: 'Plan launch',
      notes: 'Ship it on Friday',
      categoryId: 'work',
      priority: Priority.high,
      dueAt: 123,
      remindAt: task.remindAt,
      notificationId: task.notificationId,
      isDone: true,
      completedAt: null,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      sortIndex: task.sortIndex,
      deletedAt: task.deletedAt,
    );

    await dao.updateTask(updated);

    final rows = await db.query(
      'activity_log',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'occurred_at ASC',
    );

    expect(rows.map((row) => row['action']), containsAll([
      ActivityAction.titleEdited.value,
      ActivityAction.notesEdited.value,
      ActivityAction.categoryChanged.value,
      ActivityAction.priorityChanged.value,
      ActivityAction.dueDateChanged.value,
      ActivityAction.completed.value,
    ]));
  });

  test('toggleDone writes a completion log entry', () async {
    final dao = TaskDao();
    final taskId = await dao.createTask(title: 'Ship update');

    await dao.toggleDone(taskId);

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'activity_log',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );

    expect(rows, hasLength(2));
    expect(
      rows.map((row) => row['action']).toList(),
      contains(ActivityAction.completed.value),
    );
  });

  test('clearCompleted soft deletes completed tasks and logs them', () async {
    final dao = TaskDao();
    final taskId = await dao.createTask(title: 'Finish sprint');
    await dao.toggleDone(taskId);

    await dao.clearCompleted();

    final db = await AppDatabase.instance.database;
    final taskRows = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    final activityRows = await db.query(
      'activity_log',
      where: 'task_id = ? AND action = ?',
      whereArgs: [taskId, ActivityAction.deleted.value],
    );

    expect(taskRows.single['deleted_at'], isNotNull);
    expect(activityRows, isNotEmpty);
  });
}
