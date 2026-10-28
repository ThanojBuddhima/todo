import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/core/theme/motion.dart';
import 'package:todo/features/tasks/domain/priority.dart';
import 'package:todo/features/tasks/domain/subtask.dart';
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
    // A task with subtasks is completed by finishing them, so it carries no
    // checkbox of its own; swipe-to-complete remains as the manual override.
    final hasSubtasks =
        ref.watch(subtasksProvider(task.id)).valueOrNull?.isNotEmpty ?? false;
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
                        InlineSubtasks(taskId: task.id),
                      ],
                    ),
                  ),
                  if (!hasSubtasks) ...[
                    const SizedBox(width: 4),
                    AnimatedCheckbox(value: task.isDone, onChanged: onToggle),
                  ],
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

/// Subtasks shown and edited directly on the home card: a tap on the summary
/// expands the list, each row toggles in place, and the field at the bottom
/// adds one without leaving the screen.
/// Subtasks shown and edited directly on the home card. The full list is
/// always visible; the "+" in the summary row reveals the add field.
class InlineSubtasks extends ConsumerStatefulWidget {
  const InlineSubtasks({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<InlineSubtasks> createState() => _InlineSubtasksState();
}

class _InlineSubtasksState extends ConsumerState<InlineSubtasks> {
  /// Height of the summary row, held constant across load states so the card
  /// does not jump as the query resolves.
  static const double _summaryHeight = 30;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _adding = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtasksAsync = ref.watch(subtasksProvider(widget.taskId));
    return subtasksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: SizedBox(height: _summaryHeight),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          height: _summaryHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Subtasks unavailable',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ),
      data: (subtasks) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summary(context, subtasks),
            for (final subtask in subtasks)
              _SubtaskRow(
                key: ValueKey(subtask.id),
                subtask: subtask,
                onToggle: (isDone) => _run(
                  () => ref
                      .read(subtaskDaoProvider)
                      .toggleSubtask(subtask.id, isDone),
                ),
                onDelete: () => _run(
                  () => ref.read(subtaskDaoProvider).deleteSubtask(subtask.id),
                ),
              ),
            if (_adding) _addField(context) else _addButton(context),
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, List<Subtask> subtasks) {
    final theme = Theme.of(context);
    final done = subtasks.where((subtask) => subtask.isDone).length;
    final progress = subtasks.isEmpty ? 0.0 : done / subtasks.length;

    return SizedBox(
      height: _summaryHeight,
      child: Row(
        children: [
          if (subtasks.isEmpty)
            Text('No subtasks', style: theme.textTheme.labelSmall)
          else ...[
            SizedBox(
              width: 48,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: AppMotion.duration(context, AppMotion.base),
                curve: AppMotion.emphasized,
                builder: (context, value, child) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$done/${subtasks.length} subtasks',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }

  /// Sits at the bottom-left of the card, as far as possible from the
  /// checkbox column so the two are not mis-tapped.
  Widget _addButton(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Semantics(
        button: true,
        label: 'Add subtask',
        child: Material(
          color: AppColors.soft(theme.colorScheme.primary, theme.brightness),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _startAdding,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(
                Icons.add_rounded,
                size: 19,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _addField(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.bodySmall,
              onSubmitted: (_) => _add(),
              onTapOutside: (_) {
                if (_controller.text.trim().isEmpty) {
                  setState(() => _adding = false);
                }
                _focusNode.unfocus();
              },
              decoration: InputDecoration(
                hintText: 'Add a subtask',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Save subtask',
            visualDensity: VisualDensity.compact,
            onPressed: _saving ? null : _add,
            icon: Icon(Icons.check_rounded, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  void _startAdding() {
    setState(() => _adding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _add() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final added = await _run(
      () => ref.read(subtaskDaoProvider).addSubtask(widget.taskId, title),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (added) {
      _controller.clear();
      // Keep the field open and focused so several can be typed in a row.
      _focusNode.requestFocus();
    }
  }

  /// Keeps the task's own done state in step with its subtasks: finishing the
  /// last one completes the task, and reopening any one reopens it. A task with
  /// subtasks has no checkbox of its own, so this is the only thing that moves
  /// it.
  Future<void> _syncParentCompletion() async {
    final subtasks = await ref
        .read(subtaskDaoProvider)
        .getForTask(widget.taskId);
    if (subtasks.isEmpty) return;
    final taskDao = ref.read(taskDaoProvider);
    final task = await taskDao.getTaskById(widget.taskId);
    if (task == null) return;
    final allDone = subtasks.every((subtask) => subtask.isDone);
    if (allDone == task.isDone) return;
    await taskDao.toggleDone(widget.taskId);
  }

  Future<bool> _run(Future<void> Function() operation) async {
    try {
      await operation();
      await _syncParentCompletion();
      if (!mounted) return false;
      ref.invalidate(subtasksProvider(widget.taskId));
      ref.invalidate(taskActivityProvider(widget.taskId));
      ref.invalidate(tasksProvider);
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update subtasks: $error')),
      );
      return false;
    }
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    super.key,
    required this.subtask,
    required this.onToggle,
    required this.onDelete,
  });

  final Subtask subtask;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onToggle(!subtask.isDone),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        // Delete leads, then the title, with the checkbox last on the right
        // edge. Keeping the two controls at opposite ends stops the delete
        // from being hit while reaching for the checkbox.
        child: Row(
          children: [
            IconButton(
              tooltip: 'Delete subtask',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: onDelete,
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.duration(context, AppMotion.fast),
                curve: AppMotion.emphasized,
                style:
                    theme.textTheme.bodySmall?.copyWith(
                      decoration: subtask.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: subtask.isDone
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ) ??
                    const TextStyle(),
                child: Text(subtask.title),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: subtask.isDone,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) => onToggle(value ?? false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
