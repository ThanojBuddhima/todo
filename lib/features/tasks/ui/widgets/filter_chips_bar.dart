import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/features/tasks/domain/task_filter.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

class FilterChipsBar extends ConsumerWidget {
  const FilterChipsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final filterController = ref.read(taskFilterProvider.notifier);

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _modeChip(
                'All',
                TaskFilterMode.all,
                filter.mode,
                filterController.setMode,
              ),
              _modeChip(
                'Today',
                TaskFilterMode.today,
                filter.mode,
                filterController.setMode,
              ),
              _modeChip(
                'Upcoming',
                TaskFilterMode.upcoming,
                filter.mode,
                filterController.setMode,
              ),
              _modeChip(
                'Pending',
                TaskFilterMode.pending,
                filter.mode,
                filterController.setMode,
              ),
              _modeChip(
                'Done',
                TaskFilterMode.done,
                filter.mode,
                filterController.setMode,
              ),
            ],
          ),
        ),
        categoriesAsync.when(
          data: (categories) => SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('All categories'),
                  selected: filter.categoryId == null,
                  onSelected: (_) => filterController.setCategory(null),
                ),
                ...categories.map(
                  (category) => ChoiceChip(
                    label: Text(category.name),
                    selected: filter.categoryId == category.id,
                    onSelected: (_) =>
                        filterController.setCategory(category.id),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox(height: 8),
          error: (error, stackTrace) => SizedBox(
            height: 42,
            child: Center(
              child: Text(
                'Could not load categories: $error',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeChip(
    String label,
    TaskFilterMode mode,
    TaskFilterMode selectedMode,
    void Function(TaskFilterMode) onSelected,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedMode == mode,
      onSelected: (_) => onSelected(mode),
    );
  }
}
