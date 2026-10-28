import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/features/tasks/domain/task_filter.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

/// Opens the filter sheet. Selections apply immediately, so the sheet is a
/// view onto the filter rather than a form that needs confirming.
Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const FilterSheet(),
  );
}

class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  static const _modes = <(String, TaskFilterMode)>[
    ('All', TaskFilterMode.all),
    ('Today', TaskFilterMode.today),
    ('Upcoming', TaskFilterMode.upcoming),
    ('Pending', TaskFilterMode.pending),
    ('Done', TaskFilterMode.done),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(taskFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final controller = ref.read(taskFilterProvider.notifier);
    final isDefault =
        filter.mode == TaskFilterMode.all && filter.categoryId == null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Filters', style: theme.textTheme.titleLarge),
                ),
                TextButton(
                  onPressed: isDefault
                      ? null
                      : () {
                          controller.setMode(TaskFilterMode.all);
                          controller.setCategory(null);
                        },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Show', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, mode) in _modes)
                  ChoiceChip(
                    label: Text(label),
                    selected: filter.mode == mode,
                    onSelected: (_) => controller.setMode(mode),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Category', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            categoriesAsync.when(
              loading: () => const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Text(
                'Could not load categories: $error',
                style: theme.textTheme.labelSmall,
              ),
              data: (categories) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All categories'),
                    selected: filter.categoryId == null,
                    onSelected: (_) => controller.setCategory(null),
                  ),
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category.name),
                      selected: filter.categoryId == category.id,
                      onSelected: (_) => controller.setCategory(category.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter entry point for the home screen: shows the active filter and carries
/// a dot while anything is narrowed.
class FilterButton extends ConsumerWidget {
  const FilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(taskFilterProvider);
    final isDefault =
        filter.mode == TaskFilterMode.all && filter.categoryId == null;

    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppTheme.controlRadius),
      child: InkWell(
        onTap: () => showFilterSheet(context),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 18,
                color: isDefault
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDefault
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
              if (!isDefault) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
