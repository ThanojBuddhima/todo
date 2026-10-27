import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/core/theme/motion.dart';
import 'package:todo/core/utils/date_x.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/domain/task_filter.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/task_detail_screen.dart';
import 'package:todo/features/tasks/ui/task_editor_sheet.dart';
import 'package:todo/features/tasks/ui/widgets/empty_state.dart';
import 'package:todo/features/tasks/ui/widgets/animated_checkbox.dart';
import 'package:todo/features/tasks/ui/widgets/filter_chips_bar.dart';
import 'package:todo/features/tasks/ui/widgets/stat_row.dart';
import 'package:todo/features/tasks/ui/widgets/staggered_task_entrance.dart';

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

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(taskFilterProvider);
    final tasksAsync = ref.watch(filteredTasksProvider);
    final allTasksAsync = ref.watch(tasksProvider);
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                          ref.read(taskFilterProvider.notifier).setQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const FilterChipsBar(),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final allTasks = allTasksAsync.valueOrNull ?? tasks;
                final today = DateTime.now();
                final todayCount = allTasks.where((task) {
                  if (task.isDone || task.dueAt == null) return false;
                  return DateX.isSameDay(
                    DateTime.fromMillisecondsSinceEpoch(task.dueAt!),
                    today,
                  );
                }).length;
                final pendingCount = allTasks
                    .where((task) => !task.isDone)
                    .length;
                final doneCount = allTasks.where((task) => task.isDone).length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    StatRow(
                      today: todayCount,
                      pending: pendingCount,
                      done: doneCount,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => const TaskEditorSheet(),
        ),
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

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (task.priority) {
      0 => AppColors.lowPriority,
      2 => AppColors.highPriority,
      _ => AppColors.mediumPriority,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: task.isDone ? 1 : 0, end: task.isDone ? 1 : 0),
      duration: AppMotion.duration(context, AppMotion.base),
      builder: (context, desaturation, child) => ColorFiltered(
        colorFilter: _desaturationFilter(desaturation),
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final deletedTaskId = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: task.id),
                ),
              );
              if (deletedTaskId == null || !context.mounted) return;

              ref.invalidate(tasksProvider);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: const Text('Task deleted'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () async {
                        try {
                          await ref
                              .read(taskDaoProvider)
                              .restoreTask(deletedTaskId);
                          ref.invalidate(tasksProvider);
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not restore task: $error'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(99),
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
                          Text(
                            DateFormat('MMM d, y').format(
                              DateTime.fromMillisecondsSinceEpoch(task.dueAt!),
                            ),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                        _SubtaskProgress(taskId: task.id),
                      ],
                    ),
                  ),
                  AnimatedCheckbox(
                    value: task.isDone,
                    onChanged: (isDone) async {
                      try {
                        await ref.read(taskDaoProvider).toggleDone(task.id);
                        ref.invalidate(tasksProvider);
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not update task: $error'),
                          ),
                        );
                      }
                    },
                  ),
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
