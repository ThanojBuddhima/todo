import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/core/utils/date_x.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/domain/task_filter.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/task_editor_sheet.dart';
import 'package:todo/features/tasks/ui/widgets/filter_chips_bar.dart';

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
                final pendingCount = tasks.where((task) => !task.isDone).length;
                final doneCount = tasks.where((task) => task.isDone).length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _StatsRow(pending: pendingCount, done: doneCount),
                    const SizedBox(height: 16),
                    if (tasks.isEmpty)
                      const _EmptyState()
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
        ...tasks.map((task) => _TaskCard(task: task)),
    ];
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.pending, required this.done});

  final int pending;
  final int done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pending', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text('$pending', style: theme.textTheme.headlineMedium),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Done', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text('$done', style: theme.textTheme.headlineMedium),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.checklist_rounded, size: 52),
            const SizedBox(height: 16),
            Text('No tasks yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Tap the add button to plan your next step.'),
          ],
        ),
      ),
    );
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => _TaskDetail(task: task)));
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
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
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
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  final dao = ref.read(taskDaoProvider);
                  await dao.toggleDone(task.id);
                  ref.invalidate(tasksProvider);
                },
                icon: Icon(
                  task.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task.isDone ? AppColors.done : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDetail extends ConsumerWidget {
  const _TaskDetail({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          IconButton(
            onPressed: () async {
              final dao = ref.read(taskDaoProvider);
              await dao.softDelete(task.id);
              if (context.mounted) Navigator.of(context).pop();
              ref.invalidate(tasksProvider);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (task.notes?.isNotEmpty ?? false) Text(task.notes!),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TaskEditorSheet(task: task),
                );
              },
              child: const Text('Edit task'),
            ),
          ],
        ),
      ),
    );
  }
}
