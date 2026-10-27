enum ActivityAction {
  created,
  titleEdited,
  notesEdited,
  dueDateChanged,
  priorityChanged,
  categoryChanged,
  completed,
  reopened,
  subtaskAdded,
  subtaskCompleted,
  subtaskDeleted,
  reminderSet,
  reminderCleared,
  deleted,
  restored,
}

extension ActivityActionX on ActivityAction {
  String get label => switch (this) {
    ActivityAction.created => 'Created',
    ActivityAction.titleEdited => 'Title edited',
    ActivityAction.notesEdited => 'Notes edited',
    ActivityAction.dueDateChanged => 'Due date changed',
    ActivityAction.priorityChanged => 'Priority changed',
    ActivityAction.categoryChanged => 'Category changed',
    ActivityAction.completed => 'Completed',
    ActivityAction.reopened => 'Reopened',
    ActivityAction.subtaskAdded => 'Subtask added',
    ActivityAction.subtaskCompleted => 'Subtask completed',
    ActivityAction.subtaskDeleted => 'Subtask deleted',
    ActivityAction.reminderSet => 'Reminder set',
    ActivityAction.reminderCleared => 'Reminder cleared',
    ActivityAction.deleted => 'Deleted',
    ActivityAction.restored => 'Restored',
  };

  int get value {
    switch (this) {
      case ActivityAction.created:
        return 0;
      case ActivityAction.titleEdited:
        return 1;
      case ActivityAction.notesEdited:
        return 2;
      case ActivityAction.dueDateChanged:
        return 3;
      case ActivityAction.priorityChanged:
        return 4;
      case ActivityAction.categoryChanged:
        return 5;
      case ActivityAction.completed:
        return 6;
      case ActivityAction.reopened:
        return 7;
      case ActivityAction.subtaskAdded:
        return 8;
      case ActivityAction.subtaskCompleted:
        return 9;
      case ActivityAction.subtaskDeleted:
        return 10;
      case ActivityAction.reminderSet:
        return 11;
      case ActivityAction.reminderCleared:
        return 12;
      case ActivityAction.deleted:
        return 13;
      case ActivityAction.restored:
        return 14;
    }
  }

  static ActivityAction fromValue(int value) {
    return ActivityAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => ActivityAction.created,
    );
  }
}
