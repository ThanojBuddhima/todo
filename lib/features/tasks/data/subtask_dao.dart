import 'package:todo/core/db/app_database.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/subtask.dart';

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
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = '${taskId}_${DateTime.now().millisecondsSinceEpoch}';
    final subtask = Subtask(
      id: id,
      taskId: taskId,
      title: title,
      isDone: false,
      sortIndex: DateTime.now().millisecondsSinceEpoch.toDouble(),
      createdAt: now,
    );
    await db.insert('subtasks', subtask.toMap());
    await db.insert('activity_log', {
      'task_id': taskId,
      'task_title': (await db.query('tasks', where: 'id = ?', whereArgs: [taskId], limit: 1)).first['title'],
      'category_name': null,
      'action': ActivityAction.subtaskAdded.value,
      'field': 'subtask',
      'old_value': null,
      'new_value': title,
      'occurred_at': now,
    });
  }

  Future<void> toggleSubtask(String subtaskId, bool isDone) async {
    final db = await AppDatabase.instance.database;
    final row = (await db.query('subtasks', where: 'id = ?', whereArgs: [subtaskId], limit: 1)).first;
    await db.update(
      'subtasks',
      {'is_done': isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
    await db.insert('activity_log', {
      'task_id': row['task_id'],
      'task_title': (await db.query('tasks', where: 'id = ?', whereArgs: [row['task_id']], limit: 1)).first['title'],
      'category_name': null,
      'action': ActivityAction.subtaskCompleted.value,
      'field': 'subtask',
      'old_value': null,
      'new_value': row['title'],
      'occurred_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
