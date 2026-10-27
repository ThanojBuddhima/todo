import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

class TimelineTile extends StatelessWidget {
  const TimelineTile({super.key, required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final action = ActivityActionX.fromValue(entry.action);
    final color = _actionColor(context, action);
    final change = entry.oldValue != null || entry.newValue != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(_actionIcon(action), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _actionLabel(action),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: color),
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, h:mm a').format(
                          DateTime.fromMillisecondsSinceEpoch(entry.occurredAt),
                        ),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.taskTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (change) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${entry.oldValue ?? '—'} → ${entry.newValue ?? '—'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _actionColor(BuildContext context, ActivityAction action) {
    return switch (action) {
      ActivityAction.completed ||
      ActivityAction.restored ||
      ActivityAction.subtaskCompleted => AppColors.done,
      ActivityAction.deleted ||
      ActivityAction.subtaskDeleted => Theme.of(context).colorScheme.error,
      ActivityAction.reminderSet ||
      ActivityAction.reminderCleared => Theme.of(context).colorScheme.tertiary,
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  static IconData _actionIcon(ActivityAction action) {
    return switch (action) {
      ActivityAction.created => Icons.add_task,
      ActivityAction.titleEdited => Icons.title,
      ActivityAction.notesEdited => Icons.notes,
      ActivityAction.dueDateChanged => Icons.event,
      ActivityAction.priorityChanged => Icons.flag_outlined,
      ActivityAction.categoryChanged => Icons.category_outlined,
      ActivityAction.completed => Icons.check_circle_outline,
      ActivityAction.reopened => Icons.undo,
      ActivityAction.subtaskAdded => Icons.add,
      ActivityAction.subtaskCompleted => Icons.checklist,
      ActivityAction.subtaskDeleted => Icons.delete_outline,
      ActivityAction.reminderSet => Icons.notifications_active_outlined,
      ActivityAction.reminderCleared => Icons.notifications_off_outlined,
      ActivityAction.deleted => Icons.delete_outline,
      ActivityAction.restored => Icons.restore,
    };
  }

  static String _actionLabel(ActivityAction action) {
    return switch (action) {
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
  }
}
