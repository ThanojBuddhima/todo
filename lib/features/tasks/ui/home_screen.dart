import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animations/animations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/core/theme/motion.dart';
import 'package:todo/core/utils/date_x.dart';
import 'package:todo/features/reminders/notification_service.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/domain/task_filter.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/task_detail_screen.dart';
import 'package:todo/features/tasks/ui/task_editor_sheet.dart';
import 'package:todo/features/tasks/ui/widgets/empty_state.dart';
import 'package:todo/features/tasks/ui/widgets/filter_sheet.dart';
import 'package:todo/features/tasks/ui/widgets/stat_row.dart';
import 'package:todo/features/tasks/ui/widgets/staggered_task_entrance.dart';
import 'package:todo/features/tasks/ui/widgets/task_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _searchController;
  bool _doneExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const TaskEditorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(taskFilterProvider);
    final tasksAsync = ref.watch(filteredTasksProvider);
    final stats = ref.watch(taskStatsProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${_greeting(now.hour)}',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              DateFormat('EEEE, MMM d').format(now),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        ref.read(taskFilterProvider.notifier).setQuery(value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search tasks',
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(taskFilterProvider.notifier)
                                    .setQuery('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const FilterButton(),
              ],
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    StatRow(
                      today: stats.today,
                      pending: stats.pending,
                      done: stats.done,
                    ),
                    const SizedBox(height: 16),
                    if (tasks.isEmpty)
                      EmptyState(filter: filter)
                    else
                      ..._taskSections(tasks, filter),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      // A modal sheet rather than a full page: the editor is a bottom sheet, and
      // hosting it in a full-screen route left the area above it empty instead
      // of showing the task list behind a scrim.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    );
  }

  static String _greeting(int hour) {
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }

  List<Widget> _taskSections(List<Task> tasks, TaskFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final overdue = <Task>[];
    final dueToday = <Task>[];
    final dueTomorrow = <Task>[];
    final later = <Task>[];
    final done = <Task>[];

    for (final task in tasks) {
      if (task.isDone) {
        done.add(task);
        continue;
      }

      if (task.dueAt == null) {
        later.add(task);
        continue;
      }

      final due = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
      if (DateX.isSameDay(due, today)) {
        dueToday.add(task);
      } else if (DateX.isSameDay(due, tomorrow)) {
        dueTomorrow.add(task);
      } else if (due.isBefore(today)) {
        overdue.add(task);
      } else {
        later.add(task);
      }
    }

    return [
      ..._buildTaskGroup('Overdue', overdue),
      ..._buildTaskGroup('Today', dueToday),
      ..._buildTaskGroup('Tomorrow', dueTomorrow),
      ..._buildTaskGroup('Later', later),
      ..._buildTaskGroup(
        'Done',
        done,
        collapsible: true,
        expanded: filter.mode == TaskFilterMode.done || _doneExpanded,
        onToggle: () => setState(() => _doneExpanded = !_doneExpanded),
      ),
    ];
  }

  List<Widget> _buildTaskGroup(
    String title,
    List<Task> tasks, {
    bool collapsible = false,
    bool expanded = true,
    VoidCallback? onToggle,
  }) {
    if (tasks.isEmpty) return const [];

    final header = Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Text('${tasks.length}', style: Theme.of(context).textTheme.labelMedium),
        if (collapsible)
          Tooltip(
            message: expanded ? 'Collapse $title' : 'Expand $title',
            child: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ),
      ],
    );

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: collapsible
            ? Semantics(
                button: true,
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: header,
                  ),
                ),
              )
            : header,
      ),
      if (!collapsible || expanded)
        ...tasks.asMap().entries.map(
          (entry) => StaggeredTaskEntrance(
            key: ValueKey('$title-${entry.value.id}'),
            index: entry.key,
            child: _TaskCard(task: entry.value),
          ),
        ),
    ];
  }
}

class _TaskCard extends ConsumerStatefulWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final card = _isExiting
        ? const SizedBox.shrink()
        : _slidable(context, task);
    // A zero-duration AnimatedSize re-dirties its own layout when the child
    // resizes, so under reduced motion the card is returned unwrapped.
    if (AppMotion.reduced(context)) return card;
    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.emphasized,
      alignment: Alignment.topCenter,
      child: card,
    );
  }

  Widget _slidable(BuildContext context, Task task) {
    // The action panes are drawn behind the card, so they are clipped to the
    // same radius; otherwise their square corners show through the card's
    // rounded ones. The gap between rows sits outside the clip.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Slidable(
          key: ValueKey('slidable-${task.id}'),
          startActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (_) => _toggleTask(),
                backgroundColor: AppColors.done,
                foregroundColor: Colors.white,
                icon: task.isDone ? Icons.undo : Icons.check,
                label: task.isDone ? 'Reopen' : 'Complete',
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (_) => _deleteTask(context),
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                icon: Icons.delete_outline,
                label: 'Delete',
              ),
            ],
          ),
          child: TaskCard(
            task: task,
            onTap: () async {
              final deletedTaskId = await Navigator.of(context).push<String>(
                PageRouteBuilder<String>(
                  transitionDuration: AppMotion.duration(
                    context,
                    AppMotion.base,
                  ),
                  reverseTransitionDuration: AppMotion.duration(
                    context,
                    AppMotion.base,
                  ),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      TaskDetailScreen(taskId: task.id),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          SharedAxisTransition(
                            animation: animation,
                            secondaryAnimation: secondaryAnimation,
                            transitionType: SharedAxisTransitionType.scaled,
                            child: child,
                          ),
                ),
              );
              if (deletedTaskId != null && context.mounted) {
                await _showUndo(context, deletedTaskId);
              }
            },
            onToggle: (_) => _toggleTask(),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleTask() async {
    final wasDone = widget.task.isDone;
    if (!wasDone) {
      setState(() => _isExiting = true);
      await Future<void>.delayed(AppMotion.duration(context, AppMotion.base));
      if (!mounted) return;
    }

    try {
      await ref.read(taskDaoProvider).toggleDone(widget.task.id);
      ref.invalidate(tasksProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isExiting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update task: $error')));
      return;
    }

    try {
      final notificationService = ref.read(notificationServiceProvider);
      if (wasDone) {
        await _schedulePersistedReminder(widget.task);
      } else if (widget.task.notificationId != null) {
        await notificationService.cancelReminder(widget.task.notificationId!);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task updated, but its reminder failed: $error'),
        ),
      );
    }
  }

  Future<void> _deleteTask(BuildContext context) async {
    try {
      await ref.read(taskDaoProvider).softDelete(widget.task.id);
      ref.invalidate(tasksProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete task: $error')));
      return;
    }

    if (widget.task.notificationId != null) {
      try {
        await ref
            .read(notificationServiceProvider)
            .cancelReminder(widget.task.notificationId!);
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
    if (context.mounted) await _showUndo(context, widget.task.id);
  }

  Future<void> _showUndo(BuildContext context, String taskId) async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await ref.read(taskDaoProvider).restoreTask(taskId);
                ref.invalidate(tasksProvider);
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not restore task: $error')),
                );
                return;
              }

              try {
                final restoredTask = await ref
                    .read(taskDaoProvider)
                    .getTaskById(taskId);
                if (restoredTask != null) {
                  await _schedulePersistedReminder(restoredTask);
                }
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Task restored, but its reminder could not be scheduled: $error',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
  }

  Future<void> _schedulePersistedReminder(Task task) async {
    final remindAt = task.remindAt;
    if (remindAt == null ||
        !DateTime.fromMillisecondsSinceEpoch(
          remindAt,
        ).isAfter(DateTime.now())) {
      return;
    }

    final notificationId =
        task.notificationId ?? NotificationService.generateNotificationId();
    if (task.notificationId == null) {
      await ref
          .read(taskDaoProvider)
          .updateReminder(
            task.id,
            remindAt: remindAt,
            notificationId: notificationId,
          );
    }
    final notificationService = ref.read(notificationServiceProvider);
    final precision = await notificationService.currentSchedulePrecision();
    await notificationService.scheduleReminder(
      id: notificationId,
      title: task.title,
      remindAt: DateTime.fromMillisecondsSinceEpoch(remindAt),
      taskId: task.id,
      precision: precision,
    );
    if (precision == ReminderSchedulePrecision.inexact && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder restored with inexact timing.')),
      );
    }
  }
}
