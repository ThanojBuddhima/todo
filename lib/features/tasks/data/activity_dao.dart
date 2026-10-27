import 'package:todo/core/db/app_database.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

class ActivityDao {
  Future<void> insertEntry({
    required String taskTitle,
    String? taskId,
    String? categoryName,
    required int action,
    String? field,
    String? oldValue,
    String? newValue,
    int? occurredAt,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('activity_log', {
      'task_id': taskId,
      'task_title': taskTitle,
      'category_name': categoryName,
      'action': action,
      'field': field,
      'old_value': oldValue,
      'new_value': newValue,
      'occurred_at': occurredAt ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<ActivityEntry>> getRecent({int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'activity_log',
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map((row) => ActivityEntry.fromMap(row)).toList();
  }

  Future<List<ActivityEntry>> getInRange({
    required int startAtInclusive,
    required int endAtExclusive,
    int? limit,
  }) async {
    if (endAtExclusive < startAtInclusive) {
      throw ArgumentError('The activity range end must not precede its start.');
    }

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'activity_log',
      where: 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: [startAtInclusive, endAtExclusive],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map((row) => ActivityEntry.fromMap(row)).toList();
  }

  Future<List<ActivityEntry>> getForTask(String taskId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'activity_log',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'occurred_at DESC',
    );
    return rows.map((row) => ActivityEntry.fromMap(row)).toList();
  }
}
