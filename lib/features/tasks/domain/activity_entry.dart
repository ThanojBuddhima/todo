class ActivityEntry {
  final int id;
  final String? taskId;
  final String taskTitle;
  final String? categoryName;
  final int action;
  final String? field;
  final String? oldValue;
  final String? newValue;
  final int occurredAt;

  const ActivityEntry({
    required this.id,
    this.taskId,
    required this.taskTitle,
    this.categoryName,
    required this.action,
    this.field,
    this.oldValue,
    this.newValue,
    required this.occurredAt,
  });

  factory ActivityEntry.fromMap(Map<String, dynamic> map) {
    return ActivityEntry(
      id: map['id'] as int,
      taskId: map['task_id'] as String?,
      taskTitle: map['task_title'] as String,
      categoryName: map['category_name'] as String?,
      action: map['action'] as int? ?? 0,
      field: map['field'] as String?,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
      occurredAt: map['occurred_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
