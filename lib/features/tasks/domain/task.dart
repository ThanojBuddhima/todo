import 'package:todo/features/tasks/domain/priority.dart';

class Task {
  final String id;
  final String title;
  final String? notes;
  final String? categoryId;
  final Priority priority;
  final int? dueAt;
  final int? remindAt;
  final int? notificationId;
  final bool isDone;
  final int? completedAt;
  final int createdAt;
  final int updatedAt;
  final double sortIndex;
  final int? deletedAt;

  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.categoryId,
    required this.priority,
    this.dueAt,
    this.remindAt,
    this.notificationId,
    required this.isDone,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.sortIndex,
    this.deletedAt,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      categoryId: map['category_id'] as String?,
      priority: Priority.fromValue(
        map['priority'] as int? ?? Priority.medium.value,
      ),
      dueAt: map['due_at'] as int?,
      remindAt: map['remind_at'] as int?,
      notificationId: map['notification_id'] as int?,
      isDone: (map['is_done'] as int? ?? 0) == 1,
      completedAt: map['completed_at'] as int?,
      createdAt:
          map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      sortIndex: (map['sort_index'] as num?)?.toDouble() ?? 0,
      deletedAt: map['deleted_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'category_id': categoryId,
      'priority': priority.value,
      'due_at': dueAt,
      'remind_at': remindAt,
      'notification_id': notificationId,
      'is_done': isDone ? 1 : 0,
      'completed_at': completedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'sort_index': sortIndex,
      'deleted_at': deletedAt,
    };
  }
}
