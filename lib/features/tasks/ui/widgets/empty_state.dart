import 'package:flutter/material.dart';
import 'package:todo/features/tasks/domain/task_filter.dart';

class EmptyState extends StatefulWidget {
  const EmptyState({super.key, required this.filter});

  final TaskFilter filter;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final (title, message) = _copyForFilter(widget.filter);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.checklist_rounded, size: 52),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  (String, String) _copyForFilter(TaskFilter filter) {
    if (filter.query.trim().isNotEmpty) {
      return ('No matches', 'Try another search term.');
    }

    return switch (filter.mode) {
      TaskFilterMode.today => (
        'Nothing due today',
        'Enjoy the breathing room.',
      ),
      TaskFilterMode.upcoming => (
        'Nothing upcoming',
        'Tasks due after today will show here.',
      ),
      TaskFilterMode.pending => ('All caught up', 'You have no pending tasks.'),
      TaskFilterMode.done => (
        'No completed tasks',
        'Finished tasks will appear here.',
      ),
      TaskFilterMode.all => (
        'No tasks yet',
        'Tap the add button to plan your next step.',
      ),
    };
  }
}
