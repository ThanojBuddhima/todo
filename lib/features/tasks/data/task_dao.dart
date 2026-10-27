import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:todo/core/db/app_database.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/priority.dart';
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
    final rows = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<String> createTask({
    required String title,
    String? notes,
    String? categoryId,
    Priority priority = Priority.medium,
    int? dueAt,
    int? remindAt,
    int? notificationId,
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
      remindAt: remindAt,
      notificationId: notificationId,
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
        'category_name': await _categoryName(txn, categoryId),
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
      await txn.update(
        'tasks',
        updatedTask.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
      await txn.insert('activity_log', {
        'task_id': task.id,
        'task_title': task.title,
        'category_name': await _categoryName(txn, task.categoryId),
        'action': task.isDone
            ? ActivityAction.completed.value
            : ActivityAction.reopened.value,
        'field': 'done_state',
        'old_value': task.isDone ? '0' : '1',
        'new_value': task.isDone ? '1' : '0',
        'occurred_at': now,
      });
    });
  }

  Future<void> updateReminder(
    String taskId, {
    required int? remindAt,
    required int? notificationId,
  }) async {
    final db = await AppDatabase.instance.database;
    final updated = await db.update(
      'tasks',
      {
        'remind_at': remindAt,
        'notification_id': notificationId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
    if (updated == 0) {
      throw StateError('Cannot update reminder for missing task "$taskId".');
    }
  }

  Future<void> toggleDone(String taskId) async {
    final db = await AppDatabase.instance.database;
    final row = (await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    )).first;
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
      await txn.update(
        'tasks',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
      await txn.insert('activity_log', {
        'task_id': task.id,
        'task_title': task.title,
        'category_name': await _categoryName(txn, task.categoryId),
        'action': updated.isDone
            ? ActivityAction.completed.value
            : ActivityAction.reopened.value,
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
      final rows = await txn.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Cannot delete missing task "$taskId".');
      }
      final task = rows.first;
      if (task['deleted_at'] != null) {
        throw StateError('Task "$taskId" is already deleted.');
      }

      await txn.update(
        'tasks',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_log', {
        'task_id': taskId,
        'task_title': task['title'],
        'category_name': await _categoryName(
          txn,
          task['category_id'] as String?,
        ),
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
      final rows = await txn.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Cannot restore missing task "$taskId".');
      }
      final task = rows.first;
      if (task['deleted_at'] == null) {
        throw StateError('Task "$taskId" is not deleted.');
      }

      await txn.update(
        'tasks',
        {'deleted_at': null, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await txn.insert('activity_log', {
        'task_id': taskId,
        'task_title': task['title'],
        'category_name': await _categoryName(
          txn,
          task['category_id'] as String?,
        ),
        'action': ActivityAction.restored.value,
        'field': 'status',
        'old_value': 'deleted',
        'new_value': 'active',
        'occurred_at': now,
      });
    });
  }

  Future<void> clearCompleted() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update('tasks', {
      'deleted_at': now,
      'updated_at': now,
    }, where: 'is_done = 1 AND deleted_at IS NULL');
  }

  Future<void> purgeDeleted() async {
    final db = await AppDatabase.instance.database;
    await db.delete('tasks', where: 'deleted_at IS NOT NULL');
  }

  Future<void> wipeAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('activity_log');
    await db.delete('subtasks');
    await db.delete('tasks');
  }

  Future<String?> _categoryName(Transaction txn, String? categoryId) async {
    if (categoryId == null) return null;
    final categories = await txn.query(
      'categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    return categories.isEmpty ? null : categories.first['name'] as String?;
  }
}
