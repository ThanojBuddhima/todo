import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/core/theme/motion.dart';
import 'package:todo/features/tasks/domain/priority.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/widgets/animated_checkbox.dart';

class TaskCard extends ConsumerWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  final Task task;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = switch (task.priority) {
      Priority.low => AppColors.lowPriority,
      Priority.high => AppColors.highPriority,
      Priority.medium => AppColors.mediumPriority,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: task.isDone ? 1.0 : 0.0),
      duration: AppMotion.duration(context, AppMotion.base),
      builder: (context, amount, child) => ColorFiltered(
        colorFilter: _desaturationFilter(amount),
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 8,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 4,
                          height: 52,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: priorityColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 1.5,
                              ),
                            ),
                            child: const SizedBox.square(dimension: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: AppMotion.duration(context, AppMotion.base),
                          curve: AppMotion.emphasized,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                decoration: task.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isDone
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : null,
                              ) ??
                              const TextStyle(),
                          child: Text(task.title),
                        ),
                        if (task.notes?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 6),
                          Text(
                            task.notes!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (task.dueAt != null) ...[
                          const SizedBox(height: 8),
                          _DueChip(dueAt: task.dueAt!),
                        ],
                        _SubtaskProgress(taskId: task.id),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedCheckbox(value: task.isDone, onChanged: onToggle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ColorFilter _desaturationFilter(double amount) {
    const red = 0.2126;
    const green = 0.7152;
    const blue = 0.0722;
    return ColorFilter.matrix([
      1 - amount * (1 - red),
      amount * green,
      amount * blue,
      0,
      0,
      amount * red,
      1 - amount * (1 - green),
      amount * blue,
      0,
      0,
      amount * red,
      amount * green,
      1 - amount * (1 - blue),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.dueAt});

  final int dueAt;

  @override
  Widget build(BuildContext context) {
    final due = DateTime.fromMillisecondsSinceEpoch(dueAt);
    final now = DateTime.now();
    final overdue = due.isBefore(now) && !DateUtils.isSameDay(due, now);
    final color = overdue
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        DateFormat('MMM d, y · h:mm a').format(due),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _SubtaskProgress extends ConsumerWidget {
  const _SubtaskProgress({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtasksAsync = ref.watch(subtasksProvider(taskId));
    return subtasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Subtasks unavailable',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
      data: (subtasks) {
        if (subtasks.isEmpty) return const SizedBox.shrink();
        final doneCount = subtasks.where((subtask) => subtask.isDone).length;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(Icons.checklist, size: 16),
              const SizedBox(width: 4),
              Text(
                '$doneCount/${subtasks.length} subtasks',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
