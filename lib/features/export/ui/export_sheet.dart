import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/features/activity/providers/activity_providers.dart';
import 'package:todo/features/export/export_service.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/category.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

enum _ExportRangePreset { allTime, last7Days, last30Days, last90Days, custom }

class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, this.service});

  final ExportService? service;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  static const _uncategorizedKey = '__uncategorized__';

  _ExportRangePreset _rangePreset = _ExportRangePreset.last30Days;
  DateTimeRange? _customRange;
  Set<String>? _selectedCategoryIds;
  Set<ActivityAction>? _selectedActions;
  bool _includeTaskAppendix = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final range = _selectedRange();
    final activityRange = (
      startAtInclusive: range.start.millisecondsSinceEpoch,
      endAtExclusive: range.end
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch,
    );
    final activityAsync = ref.watch(activityRangeProvider(activityRange));
    final categories = categoriesAsync.valueOrNull;
    final selectedCategoryNames = categories == null
        ? null
        : _categoryFilter(categories);
    final selectedActionValues = _selectedActions
        ?.map((action) => action.value)
        .toSet();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Export activity report',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  DropdownButtonFormField<_ExportRangePreset>(
                    key: const ValueKey('export-range-preset'),
                    borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                    dropdownColor: Theme.of(context).cardTheme.color,
                    initialValue: _rangePreset,
                    decoration: const InputDecoration(labelText: 'Date range'),
                    items: const [
                      DropdownMenuItem(
                        value: _ExportRangePreset.allTime,
                        child: Text('All time'),
                      ),
                      DropdownMenuItem(
                        value: _ExportRangePreset.last7Days,
                        child: Text('Last 7 days'),
                      ),
                      DropdownMenuItem(
                        value: _ExportRangePreset.last30Days,
                        child: Text('Last 30 days'),
                      ),
                      DropdownMenuItem(
                        value: _ExportRangePreset.last90Days,
                        child: Text('Last 90 days'),
                      ),
                      DropdownMenuItem(
                        value: _ExportRangePreset.custom,
                        child: Text('Custom range'),
                      ),
                    ],
                    onChanged: (preset) {
                      if (preset == null) return;
                      if (preset == _ExportRangePreset.custom) {
                        _pickCustomRange();
                      } else {
                        setState(() => _rangePreset = preset);
                      }
                    },
                  ),
                  if (_rangePreset == _ExportRangePreset.custom &&
                      _customRange != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${DateFormat.yMMMd().format(_customRange!.start)} to '
                        '${DateFormat.yMMMd().format(_customRange!.end)}',
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: activityAsync.when(
                      data: (entries) {
                        final filtered = entries.where((entry) {
                          final matchesCategory =
                              selectedCategoryNames == null ||
                              selectedCategoryNames.contains(
                                entry.categoryName ?? 'Uncategorized',
                              );
                          final matchesAction =
                              selectedActionValues == null ||
                              selectedActionValues.contains(entry.action);
                          return matchesCategory && matchesAction;
                        });
                        final taskIds = filtered
                            .map((entry) => entry.taskId ?? entry.taskTitle)
                            .toSet();
                        return Text(
                          '${filtered.length} activities across '
                          '${taskIds.length} tasks',
                          key: const ValueKey('export-activity-count'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      },
                      loading: () => const Text('Counting activities...'),
                      error: (error, stackTrace) =>
                          Text('Could not count activities: $error'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text('Categories'),
                    subtitle: Text(_categoryFilterSummary()),
                    children: [
                      categoriesAsync.when(
                        data: (categories) => Column(
                          children: [
                            for (final category in categories)
                              CheckboxListTile(
                                key: ValueKey('export-category-${category.id}'),
                                dense: true,
                                title: Text(category.name),
                                value: _isCategorySelected(category.id),
                                onChanged: (selected) => _toggleCategory(
                                  category.id,
                                  selected ?? false,
                                  categories,
                                ),
                              ),
                            CheckboxListTile(
                              key: const ValueKey(
                                'export-category-uncategorized',
                              ),
                              dense: true,
                              title: const Text('Uncategorized'),
                              value: _isCategorySelected(_uncategorizedKey),
                              onChanged: (selected) => _toggleCategory(
                                _uncategorizedKey,
                                selected ?? false,
                                categories,
                              ),
                            ),
                          ],
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, stackTrace) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Could not load categories: $error'),
                        ),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text('Actions'),
                    subtitle: Text(_actionFilterSummary()),
                    children: [
                      for (final action in ActivityAction.values)
                        CheckboxListTile(
                          key: ValueKey('export-action-${action.value}'),
                          dense: true,
                          title: Text(action.label),
                          value: _isActionSelected(action),
                          onChanged: (selected) =>
                              _toggleAction(action, selected ?? false),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    key: const ValueKey('export-task-appendix'),
                    title: const Text('Include per-task appendix'),
                    value: _includeTaskAppendix,
                    onChanged: (value) =>
                        setState(() => _includeTaskAppendix = value),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isExporting ? null : _export,
                  icon: _isExporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _isExporting ? 'Generating report' : 'Export PDF',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTimeRange _selectedRange() {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = switch (_rangePreset) {
      _ExportRangePreset.allTime => DateTime(1970),
      _ExportRangePreset.last7Days => today.subtract(const Duration(days: 6)),
      _ExportRangePreset.last30Days => today.subtract(const Duration(days: 29)),
      _ExportRangePreset.last90Days => today.subtract(const Duration(days: 89)),
      _ExportRangePreset.custom =>
        _customRange?.start ?? today.subtract(const Duration(days: 29)),
    };
    final end = _rangePreset == _ExportRangePreset.custom
        ? _customRange?.end ?? today
        : today;
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _pickCustomRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: today,
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: today,
          ),
    );
    if (range != null && mounted) {
      setState(() {
        _rangePreset = _ExportRangePreset.custom;
        _customRange = range;
      });
    }
  }

  bool _isCategorySelected(String categoryId) =>
      _selectedCategoryIds == null ||
      _selectedCategoryIds!.contains(categoryId);

  void _toggleCategory(
    String categoryId,
    bool selected,
    List<Category> categories,
  ) {
    final allIds = {
      ...categories.map((category) => category.id),
      _uncategorizedKey,
    };
    final next = _selectedCategoryIds?.toSet() ?? allIds;
    if (selected) {
      next.add(categoryId);
    } else {
      next.remove(categoryId);
    }
    setState(() => _selectedCategoryIds = next);
  }

  Set<String>? _categoryFilter(List<Category> categories) {
    final selected = _selectedCategoryIds;
    if (selected == null) return null;
    return {
      for (final category in categories)
        if (selected.contains(category.id)) ...{category.id, category.name},
      if (selected.contains(_uncategorizedKey)) 'Uncategorized',
    };
  }

  String _categoryFilterSummary() => _selectedCategoryIds == null
      ? 'All categories'
      : '${_selectedCategoryIds!.length} selected';

  bool _isActionSelected(ActivityAction action) =>
      _selectedActions == null || _selectedActions!.contains(action);

  void _toggleAction(ActivityAction action, bool selected) {
    final next = _selectedActions?.toSet() ?? ActivityAction.values.toSet();
    if (selected) {
      next.add(action);
    } else {
      next.remove(action);
    }
    setState(() => _selectedActions = next);
  }

  String _actionFilterSummary() => _selectedActions == null
      ? 'All actions'
      : '${_selectedActions!.length} selected';

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final categories = await ref.read(categoriesProvider.future);
      final range = _selectedRange();
      final file = await (widget.service ?? ExportService()).exportReport(
        appName: 'Todo',
        startDate: range.start,
        endDate: range.end,
        includeTaskAppendix: _includeTaskAppendix,
        categoryNames: _categoryFilter(categories),
        actionValues: _selectedActions?.map((action) => action.value).toSet(),
      );
      if (mounted) Navigator.of(context).pop<File>(file);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export report: $error')),
      );
    }
  }
}
