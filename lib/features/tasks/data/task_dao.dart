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
      await _insertActivity(
        txn,
        taskId: task.id,
        taskTitle: task.title,
        categoryId: categoryId,
        action: ActivityAction.created,
        field: 'title',
        newValue: task.title,
        occurredAt: now,
      );
    });
    return id;
  }

  Future<void> updateTask(Task task) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [task.id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Cannot update missing task "${task.id}".');
      }

      final previous = Task.fromMap(rows.first);
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

      await txn.update(
        'tasks',
        updatedTask.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );

      if (previous.title != task.title) {
        await _insertActivity(
          txn,
          taskId: task.id,
          taskTitle: task.title,
          categoryId: task.categoryId,
          action: ActivityAction.titleEdited,
          field: 'title',
          oldValue: previous.title,
          newValue: task.title,
          occurredAt: now,
        );
      }

      if (previous.notes != task.notes) {
        await _insertActivity(
          txn,
          taskId: task.id,
          taskTitle: task.title,
          categoryId: task.categoryId,
          action: ActivityAction.notesEdited,
          field: 'notes',
          oldValue: previous.notes,
          newValue: task.notes,
          occurredAt: now,
        );
      }

      if (previous.categoryId != task.categoryId) {
        await _insertActivity(
          txn,
          taskId: task.id,
          taskTitle: task.title,
          categoryId: task.categoryId,
          action: ActivityAction.categoryChanged,
          field: 'category',
          oldValue: previous.categoryId,
          newValue: task.categoryId,
          occurredAt: now,
        );
      }

      if (previous.priority != task.priority) {
        await _insertActivity(
          txn,
          taskId: task.id,
          taskTitle: task.title,
          categoryId: task.categoryId,
          action: ActivityAction.priorityChanged,
          field: 'priority',
          oldValue: previous.priority.value.toString(),
          newValue: task.priority.value.toString(),
          occurredAt: now,
        );
      }

      if (previous.dueAt != task.dueAt) {
        await _insertActivity(
          txn,
          taskId: task.id,
          taskTitle: task.title,
          categoryId: task.categoryId,
          action: ActivityAction.dueDateChanged,
          field: 'due_date',
          oldValue: previous.dueAt?.toString(),
          newValue: task.dueAt?.toString(),
          occurredAt: now,
        );
      }

      if (previous.isDone != task.isDone) {
        await _insertActivity(
          txn,
          taskId: task.id,
          taskTitle: task.title,
          categoryId: task.categoryId,
          action: task.isDone
              ? ActivityAction.completed
              : ActivityAction.reopened,
          field: 'done_state',
          oldValue: previous.isDone ? '1' : '0',
          newValue: task.isDone ? '1' : '0',
          occurredAt: now,
        );
      }
    });
  }

  Future<void> updateReminder(
    String taskId, {
    required int? remindAt,
    required int? notificationId,
  }) async {
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
        throw StateError('Cannot update reminder for missing task "$taskId".');
      }

      final task = Task.fromMap(rows.first);
      final previousReminder = task.remindAt;
      if (previousReminder == remindAt &&
          task.notificationId == notificationId) {
        return;
      }

      await txn.update(
        'tasks',
        {
          'remind_at': remindAt,
          'notification_id': notificationId,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      await _insertActivity(
        txn,
        taskId: task.id,
        taskTitle: task.title,
        categoryId: task.categoryId,
        action: remindAt == null
            ? ActivityAction.reminderCleared
            : ActivityAction.reminderSet,
        field: 'reminder',
        oldValue: previousReminder?.toString(),
        newValue: remindAt?.toString(),
        occurredAt: now,
      );
    });
  }

  Future<void> toggleDone(String taskId) async {
    final db = await AppDatabase.instance.database;
    final row = (await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    )).firstOrNull;
    if (row == null) {
      throw StateError('Cannot toggle missing task "$taskId".');
    }

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
      await _insertActivity(
        txn,
        taskId: task.id,
        taskTitle: task.title,
        categoryId: task.categoryId,
        action: updated.isDone
            ? ActivityAction.completed
            : ActivityAction.reopened,
        field: 'done_state',
        oldValue: task.isDone ? '1' : '0',
        newValue: updated.isDone ? '1' : '0',
        occurredAt: now,
      );
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
      final taskRow = rows.first;
      if (taskRow['deleted_at'] != null) {
        throw StateError('Task "$taskId" is already deleted.');
      }

      await txn.update(
        'tasks',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      await _insertActivity(
        txn,
        taskId: taskId,
        taskTitle: taskRow['title'] as String,
        categoryId: taskRow['category_id'] as String?,
        action: ActivityAction.deleted,
        field: 'status',
        oldValue: 'active',
        newValue: 'deleted',
        occurredAt: now,
      );
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
      await _insertActivity(
        txn,
        taskId: taskId,
        taskTitle: task['title'] as String,
        categoryId: task['category_id'] as String?,
        action: ActivityAction.restored,
        field: 'status',
        oldValue: 'deleted',
        newValue: 'active',
        occurredAt: now,
      );
    });
  }

  Future<void> clearCompleted() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'tasks',
        where: 'is_done = 1 AND deleted_at IS NULL',
      );
      for (final row in rows) {
        final task = Task.fromMap(row);
        await txn.update(
          'tasks',
          {'deleted_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [task.id],
        );
        await _insertActivity(
          txn,
          taskId: task.id,
          taskTitle: task.title,
          categoryId: task.categoryId,
          action: ActivityAction.deleted,
          field: 'status',
          oldValue: 'completed',
          newValue: 'deleted',
          occurredAt: now,
        );
      }
    });
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

  /// Moves [taskId] so it sits between [previousId] and [nextId], writing only
  /// the moved row: the new sort_index is the midpoint of its neighbours, so
  /// the siblings keep the values they already have.
  ///
  /// Pass a null neighbour for the ends of the list. Returns the stored index.
  Future<double> reorderTask(
    String taskId, {
    String? previousId,
    String? nextId,
  }) async {
    final db = await AppDatabase.instance.database;
    final previous = await _sortIndexOf(db, previousId);
    final next = await _sortIndexOf(db, nextId);

    final double sortIndex;
    if (previous != null && next != null) {
      sortIndex = (previous + next) / 2;
    } else if (previous != null) {
      sortIndex = previous + 1;
    } else if (next != null) {
      sortIndex = next - 1;
    } else {
      sortIndex = 0;
    }

    await db.update(
      'tasks',
      {'sort_index': sortIndex},
      where: 'id = ?',
      whereArgs: [taskId],
    );
    return sortIndex;
  }

  Future<double?> _sortIndexOf(DatabaseExecutor db, String? taskId) async {
    if (taskId == null) return null;
    final rows = await db.query(
      'tasks',
      columns: ['sort_index'],
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['sort_index'] as num).toDouble();
  }

  Future<void> _insertActivity(
    Transaction txn, {
    required String taskId,
    required String taskTitle,
    String? categoryId,
    required ActivityAction action,
    String? field,
    String? oldValue,
    String? newValue,
    required int occurredAt,
  }) async {
    await txn.insert('activity_log', {
      'task_id': taskId,
      'task_title': taskTitle,
      'category_name': await _categoryName(txn, categoryId),
      'action': action.value,
      'field': field,
      'old_value': oldValue,
      'new_value': newValue,
      'occurred_at': occurredAt,
    });
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
