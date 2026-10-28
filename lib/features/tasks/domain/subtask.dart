class Subtask {
  final String id;
  final String taskId;
  final String title;
  final bool isDone;
  final double sortIndex;
  final int createdAt;

  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isDone,
    required this.sortIndex,
    required this.createdAt,
  });

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      title: map['title'] as String,
      isDone: (map['is_done'] as int? ?? 0) == 1,
      sortIndex: (map['sort_index'] as num?)?.toDouble() ?? 0,
      createdAt:
          map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'title': title,
      'is_done': isDone ? 1 : 0,
      'sort_index': sortIndex,
      'created_at': createdAt,
    };
  }
}
