import 'package:uuid/uuid.dart';
import 'package:todo/core/db/app_database.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/task.dart';

class TaskDao {
  Future<List<Task>> getTasks() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'tasks',
      where: 'deleted_at IS NULL',
      orderBy: 'sort_index ASC, created_at DESC',
    );
    return rows.map((row) => Task.fromMap(row)).toList();
  }

  Future<Task?> getTaskById(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<String> createTask({
    required String title,
    String? notes,
    String? categoryId,
    int priority = 1,
    int? dueAt,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    final task = Task(
      id: id,
      title: title,
      notes: notes,
      categoryId: categoryId,
      priority: priority,
      dueAt: dueAt,
      isDone: false,
      createdAt: now,
      updatedAt: now,
      sortIndex: now.toDouble(),
    );

    await db.transaction((txn) async {
      await txn.insert('tasks', task.toMap());
      await txn.insert('activity_log', {
        'task_id': task.id,
        'task_title': task.title,
        'category_name': categoryId,
        'action': ActivityAction.created.value,
        'field': 'title',
        'old_value': null,
        'new_value': task.title,
        'occurred_at': now,
      });
    });
    return id;
  }

  Future<void> updateTask(Task task) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedTask = Task(
      id: task.id,
      title: task.title,
      notes: task.notes,
      categoryId: task.categoryId,
      priority: task.priority,
      dueAt: task.dueAt,
      remindAt: task.remindAt,
      notificationId: task.notificationId,
      isDone: task.isDone,
      completedAt: task.completedAt,
      createdAt: task.createdAt,
      updatedAt: now,
      sortIndex: task.sortIndex,
      deletedAt: task.deletedAt,
    );

    await db.transaction((txn) async {
      await txn.update('tasks', updatedTask.toMap(), where: 'id = ?', whereArgs: [task.id]);
      await txn.insert('activity_log', {
        'task_id': task.id,
        'task_title': task.title,
        'category_name': task.categoryId,
        'action': task.isDone ? ActivityAction.completed.value : ActivityAction.reopened.value,
        'field': 'done_state',
        'old_value': task.isDone ? '0' : '1',
        'new_value': task.isDone ? '1' : '0',
        'occurred_at': now,
      });
    });
  }

  Future<void> toggleDone(String taskId) async {
    final db = await AppDatabase.instance.database;
    final row = (await db.query('tasks', where: 'id = ?', whereArgs: [taskId], limit: 1)).first;
    final task = Task.fromMap(row);
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = Task(
      id: task.id,
      title: task.title,
      notes: task.notes,
      categoryId: task.categoryId,
      priority: task.priority,
      dueAt: task.dueAt,
      remindAt: task.remindAt,
      notificationId: task.notificationId,
      isDone: !task.isDone,
      completedAt: !task.isDone ? now : null,
      createdAt: task.createdAt,
      updatedAt: now,
      sortIndex: task.sortIndex,
      deletedAt: task.deletedAt,
    );
    await db.transaction((txn) async {
      await txn.update('tasks', updated.toMap(), where: 'id = ?', whereArgs: [task.id]);
      await txn.insert('activity_log', {
        'task_id': task.id,
        'task_title': task.title,
        'category_name': task.categoryId,
        'action': updated.isDone ? ActivityAction.completed.value : ActivityAction.reopened.value,
        'field': 'done_state',
        'old_value': task.isDone ? '1' : '0',
        'new_value': updated.isDone ? '1' : '0',
        'occurred_at': now,
      });
    });
  }

  Future<void> softDelete(String taskId) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_log', {
        'task_id': taskId,
        'task_title': (await txn.query('tasks', where: 'id = ?', whereArgs: [taskId], limit: 1)).first['title'],
        'category_name': null,
        'action': ActivityAction.deleted.value,
        'field': 'status',
        'old_value': 'active',
        'new_value': 'deleted',
        'occurred_at': now,
      });
    });
  }

  Future<void> restoreTask(String taskId) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        {'deleted_at': null, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_log', {
        'task_id': taskId,
        'task_title': (await txn.query('tasks', where: 'id = ?', whereArgs: [taskId], limit: 1)).first['title'],
        'category_name': null,
        'action': ActivityAction.restored.value,
        'field': 'status',
        'old_value': 'deleted',
        'new_value': 'active',
        'occurred_at': now,
      });
    });
  }
}
