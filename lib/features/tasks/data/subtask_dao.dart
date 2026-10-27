import 'package:sqflite/sqflite.dart';
import 'package:todo/core/db/app_database.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/subtask.dart';
import 'package:uuid/uuid.dart';

class SubtaskDao {
  Future<List<Subtask>> getForTask(String taskId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'sort_index ASC, created_at ASC',
    );
    return rows.map((row) => Subtask.fromMap(row)).toList();
  }

  Future<void> addSubtask(String taskId, String title) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Subtask title cannot be empty.',
      );
    }

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final subtask = Subtask(
      id: const Uuid().v4(),
      taskId: taskId,
      title: normalizedTitle,
      isDone: false,
      sortIndex: now.toDouble(),
      createdAt: now,
    );

    await db.transaction((txn) async {
      final task = await _requireTask(txn, taskId);
      final lastRows = await txn.query(
        'subtasks',
        columns: ['MAX(sort_index) AS max_sort'],
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      final maxSort = (lastRows.first['max_sort'] as num?)?.toDouble();
      final orderedSubtask = Subtask(
        id: subtask.id,
        taskId: taskId,
        title: normalizedTitle,
        isDone: false,
        sortIndex: maxSort == null ? 0 : maxSort + 1,
        createdAt: now,
      );
      await txn.insert('subtasks', orderedSubtask.toMap());
      await _insertActivity(
        txn,
        task,
        action: ActivityAction.subtaskAdded,
        field: 'subtask',
        newValue: normalizedTitle,
        occurredAt: now,
      );
    });
  }

  Future<void> toggleSubtask(String subtaskId, bool isDone) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'subtasks',
        where: 'id = ?',
        whereArgs: [subtaskId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Cannot toggle missing subtask "$subtaskId".');
      }

      final subtask = Subtask.fromMap(rows.first);
      if (subtask.isDone == isDone) return;
      final task = await _requireTask(txn, subtask.taskId);
      await txn.update(
        'subtasks',
        {'is_done': isDone ? 1 : 0},
        where: 'id = ?',
        whereArgs: [subtaskId],
      );
      await _insertActivity(
        txn,
        task,
        action: ActivityAction.subtaskCompleted,
        field: 'subtask_status',
        oldValue: subtask.isDone ? 'done' : 'pending',
        newValue: isDone ? 'done' : 'pending',
        occurredAt: now,
      );
    });
  }

  Future<void> renameSubtask(String subtaskId, String title) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Subtask title cannot be empty.',
      );
    }

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'subtasks',
        where: 'id = ?',
        whereArgs: [subtaskId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Cannot rename missing subtask "$subtaskId".');
      }

      final subtask = Subtask.fromMap(rows.first);
      if (subtask.title == normalizedTitle) return;
      final task = await _requireTask(txn, subtask.taskId);
      await txn.update(
        'subtasks',
        {'title': normalizedTitle},
        where: 'id = ?',
        whereArgs: [subtaskId],
      );
      await _insertActivity(
        txn,
        task,
        action: ActivityAction.titleEdited,
        field: 'subtask_title',
        oldValue: subtask.title,
        newValue: normalizedTitle,
        occurredAt: now,
      );
    });
  }

  Future<void> deleteSubtask(String subtaskId) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'subtasks',
        where: 'id = ?',
        whereArgs: [subtaskId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Cannot delete missing subtask "$subtaskId".');
      }

      final subtask = Subtask.fromMap(rows.first);
      final task = await _requireTask(txn, subtask.taskId);
      await txn.delete('subtasks', where: 'id = ?', whereArgs: [subtaskId]);
      await _insertActivity(
        txn,
        task,
        action: ActivityAction.subtaskDeleted,
        field: 'subtask',
        oldValue: subtask.title,
        occurredAt: now,
      );
    });
  }

  Future<void> reorderSubtasks(String taskId, List<String> orderedIds) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final task = await _requireTask(txn, taskId);
      final rows = await txn.query(
        'subtasks',
        columns: ['id', 'title'],
        where: 'task_id = ?',
        whereArgs: [taskId],
        orderBy: 'sort_index ASC, created_at ASC',
      );
      final currentIds = rows.map((row) => row['id'] as String).toSet();
      if (orderedIds.length != currentIds.length ||
          orderedIds.toSet().length != orderedIds.length ||
          !orderedIds.toSet().containsAll(currentIds)) {
        throw ArgumentError.value(
          orderedIds,
          'orderedIds',
          'Must contain each subtask for the task exactly once.',
        );
      }

      final oldIds = rows.map((row) => row['id'] as String).toList();
      var hasChanged = false;
      for (var index = 0; index < orderedIds.length; index++) {
        if (oldIds[index] != orderedIds[index]) {
          hasChanged = true;
          break;
        }
      }
      if (!hasChanged) return;
      final titleById = {
        for (final row in rows) row['id'] as String: row['title'] as String,
      };
      final oldOrder = oldIds.map((id) => titleById[id]!).join(' → ');
      final newOrder = orderedIds.map((id) => titleById[id]!).join(' → ');

      for (var index = 0; index < orderedIds.length; index++) {
        await txn.update(
          'subtasks',
          {'sort_index': index.toDouble()},
          where: 'id = ? AND task_id = ?',
          whereArgs: [orderedIds[index], taskId],
        );
      }
      await _insertActivity(
        txn,
        task,
        action: ActivityAction.titleEdited,
        field: 'subtask_order',
        oldValue: oldOrder,
        newValue: newOrder,
        occurredAt: now,
      );
    });
  }

  Future<Map<String, Object?>> _requireTask(
    Transaction txn,
    String taskId,
  ) async {
    final rows = await txn.query(
      'tasks',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'Cannot change subtasks for missing or deleted task "$taskId".',
      );
    }
    return rows.first;
  }

  Future<void> _insertActivity(
    Transaction txn,
    Map<String, Object?> task, {
    required ActivityAction action,
    required String field,
    String? oldValue,
    String? newValue,
    required int occurredAt,
  }) async {
    final categoryId = task['category_id'] as String?;
    String? categoryName;
    if (categoryId != null) {
      final categoryRows = await txn.query(
        'categories',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );
      categoryName = categoryRows.isEmpty
          ? null
          : categoryRows.first['name'] as String?;
    }

    await txn.insert('activity_log', {
      'task_id': task['id'],
      'task_title': task['title'],
      'category_name': categoryName,
      'action': action.value,
      'field': field,
      'old_value': oldValue,
      'new_value': newValue,
      'occurred_at': occurredAt,
    });
  }
}
