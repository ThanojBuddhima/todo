import 'package:todo/core/utils/date_x.dart';
import 'package:todo/features/tasks/domain/task.dart';

enum TaskFilterMode { all, today, upcoming, pending, done }

class TaskFilter {
  final TaskFilterMode mode;
  final String? categoryId;
  final String query;

  const TaskFilter({
    this.mode = TaskFilterMode.all,
    this.categoryId,
    this.query = '',
  });

  bool matches(Task task) {
    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isNotEmpty) {
      final haystack = '${task.title} ${task.notes ?? ''}'.toLowerCase();
      if (!haystack.contains(trimmedQuery)) {
        return false;
      }
    }

    if (categoryId != null &&
        categoryId!.isNotEmpty &&
        task.categoryId != categoryId) {
      return false;
    }

    switch (mode) {
      case TaskFilterMode.all:
        return true;
      case TaskFilterMode.pending:
        return !task.isDone;
      case TaskFilterMode.done:
        return task.isDone;
      case TaskFilterMode.today:
        return _matchesSameDay(task, DateTime.now());
      case TaskFilterMode.upcoming:
        if (task.isDone || task.dueAt == null) return false;
        final dueDate = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        return dueDate.isAfter(startOfToday) && !DateX.isSameDay(dueDate, now);
    }
  }

  bool _matchesSameDay(Task task, DateTime now) {
    if (task.isDone || task.dueAt == null) return false;
    final dueDate = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    return DateX.isSameDay(dueDate, now);
  }

  TaskFilter copyWith({
    TaskFilterMode? mode,
    String? categoryId,
    bool clearCategory = false,
    String? query,
  }) {
    return TaskFilter(
      mode: mode ?? this.mode,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      query: query ?? this.query,
    );
  }
}
