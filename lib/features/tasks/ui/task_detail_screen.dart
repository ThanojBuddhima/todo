import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/task_editor_sheet.dart';
import 'package:todo/features/tasks/ui/widgets/task_subtasks_section.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskByIdProvider(taskId));
    final activityAsync = ref.watch(taskActivityProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          IconButton(
            tooltip: 'Delete task',
            onPressed: () async {
              final dao = ref.read(taskDaoProvider);
              Task? task;
              try {
                task = await dao.getTaskById(taskId);
                await dao.softDelete(taskId);
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not delete task: $error')),
                );
                return;
              }
              if (task != null && task.notificationId != null) {
                try {
                  await ref
                      .read(notificationServiceProvider)
                      .cancelReminder(task.notificationId!);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Task deleted, but its reminder could not be canceled: $error',
                      ),
                    ),
                  );
                }
              }
              if (context.mounted) {
                Navigator.of(context).pop(taskId);
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load task: $error'),
          ),
        ),
        data: (task) {
          if (task == null || task.deletedAt != null) {
            return const Center(
              child: Text('This task is no longer available.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (task.notes?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Text(task.notes!),
              ],
              if (task.dueAt != null) ...[
                const SizedBox(height: 12),
                LabelValue(
                  icon: Icons.schedule_outlined,
                  label: 'Due',
                  value: DateFormat(
                    'EEE, MMM d · h:mm a',
                  ).format(DateTime.fromMillisecondsSinceEpoch(task.dueAt!)),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => TaskEditorSheet(task: task),
                  );
                  ref.invalidate(taskByIdProvider(taskId));
                  ref.invalidate(taskActivityProvider(taskId));
                  ref.invalidate(tasksProvider);
                },
                child: const Text('Edit task'),
              ),
              const SizedBox(height: 20),
              TaskSubtasksSection(taskId: taskId),
              const SizedBox(height: 24),
              Text('Activity', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              activityAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Text('Could not load task activity: $error'),
                data: (entries) => entries.isEmpty
                    ? Text(
                        'No activity recorded yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : Column(
                        children: entries
                            .map((entry) => _ActivityRow(entry: entry))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LabelValue extends StatelessWidget {
  const LabelValue({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text('$label: '),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final action = ActivityActionX.fromValue(entry.action);
    final message = switch (action) {
      ActivityAction.created => 'Task created',
      ActivityAction.titleEdited =>
        entry.field == 'subtask_title'
            ? 'Subtask renamed: ${entry.oldValue ?? ''} → ${entry.newValue ?? ''}'
            : 'Title changed: ${entry.oldValue ?? ''} → ${entry.newValue ?? ''}',
      ActivityAction.notesEdited => 'Notes updated',
      ActivityAction.dueDateChanged => 'Due date updated',
      ActivityAction.priorityChanged => 'Priority updated',
      ActivityAction.categoryChanged => 'Category updated',
      ActivityAction.completed => 'Task completed',
      ActivityAction.reopened => 'Task reopened',
      ActivityAction.subtaskAdded => 'Subtask added: ${entry.newValue ?? ''}',
      ActivityAction.subtaskCompleted =>
        'Subtask status updated: ${entry.newValue ?? ''}',
      ActivityAction.subtaskDeleted =>
        'Subtask deleted: ${entry.oldValue ?? ''}',
      ActivityAction.reminderSet => 'Reminder set',
      ActivityAction.reminderCleared => 'Reminder cleared',
      ActivityAction.deleted => 'Task deleted',
      ActivityAction.restored => 'Task restored',
    };

    return ListTile(
      leading: Icon(_iconFor(action)),
      title: Text(message),
      subtitle: Text(
        DateFormat(
          'MMM d, y · h:mm a',
        ).format(DateTime.fromMillisecondsSinceEpoch(entry.occurredAt)),
      ),
      dense: true,
    );
  }

  IconData _iconFor(ActivityAction action) => switch (action) {
    ActivityAction.created => Icons.add_circle_outline,
    ActivityAction.completed => Icons.check_circle_outline,
    ActivityAction.reopened => Icons.refresh,
    ActivityAction.deleted ||
    ActivityAction.subtaskDeleted => Icons.delete_outline,
    ActivityAction.subtaskAdded => Icons.playlist_add,
    ActivityAction.subtaskCompleted => Icons.checklist,
    ActivityAction.reminderSet ||
    ActivityAction.reminderCleared => Icons.notifications_outlined,
    _ => Icons.edit_outlined,
  };
}
