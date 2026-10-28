import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:todo/features/activity/providers/activity_providers.dart';
import 'package:todo/features/activity/ui/widgets/timeline_tile.dart';
import 'package:todo/features/export/ui/export_sheet.dart';
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTimeRange? _dateRange;
  ActivityAction? _actionFilter;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final range = (
      startAtInclusive: _dateRange == null
          ? 0
          : DateUtils.dateOnly(_dateRange!.start).millisecondsSinceEpoch,
      endAtExclusive: _dateRange == null
          ? today.add(const Duration(days: 1)).millisecondsSinceEpoch
          : DateUtils.dateOnly(
              _dateRange!.end,
            ).add(const Duration(days: 1)).millisecondsSinceEpoch,
    );
    final activityAsync = ref.watch(activityRangeProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            key: const ValueKey('open-export-sheet'),
            tooltip: 'Export report',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              final file = await showModalBottomSheet<File>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => const ExportSheet(),
              );
              if (file == null || !context.mounted) return;
              await _showExportActions(file);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('history-date-filter'),
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_dateRangeLabel()),
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    tooltip: 'Clear date range',
                    onPressed: () => setState(() => _dateRange = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    key: const ValueKey('history-action-filter-all'),
                    label: const Text('All actions'),
                    selected: _actionFilter == null,
                    onSelected: (_) => setState(() => _actionFilter = null),
                  ),
                ),
                for (final action in ActivityAction.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      key: ValueKey('history-action-filter-${action.value}'),
                      label: Text(action.label),
                      selected: _actionFilter == action,
                      onSelected: (_) => setState(() => _actionFilter = action),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: activityAsync.when(
              data: (entries) {
                final filteredEntries = _actionFilter == null
                    ? entries
                    : entries
                          .where(
                            (entry) =>
                                ActivityActionX.fromValue(entry.action) ==
                                _actionFilter,
                          )
                          .toList();
                if (filteredEntries.isEmpty) {
                  return const Center(child: Text('No activity in this range'));
                }
                return _buildTimeline(filteredEntries);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Could not load history: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: today,
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: today,
          ),
    );
    if (selected != null && mounted) {
      setState(() => _dateRange = selected);
    }
  }

  String _dateRangeLabel() {
    if (_dateRange == null) return 'All dates';
    final format = DateFormat.yMMMd();
    return '${format.format(_dateRange!.start)} to '
        '${format.format(_dateRange!.end)}';
  }

  Future<void> _showExportActions(File file) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report ready'),
        content: Text('Saved ${file.uri.pathSegments.last} in app documents.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _previewReport(file);
            },
            child: const Text('Preview'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _shareReport(file);
            },
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _openReport(file);
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _previewReport(File file) async {
    try {
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        name: file.uri.pathSegments.last,
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      _showExportActionError('preview', error);
    }
  }

  Future<void> _shareReport(File file) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Todo activity report'),
      );
      if (result.status == ShareResultStatus.unavailable) {
        _showExportActionError(
          'share',
          StateError('The system share sheet is unavailable.'),
        );
      }
    } catch (error) {
      _showExportActionError('share', error);
    }
  }

  Future<void> _openReport(File file) async {
    try {
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        _showExportActionError('open', StateError(result.message));
      }
    } catch (error) {
      _showExportActionError('open', error);
    }
  }

  void _showExportActionError(String action, Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not $action report: $error')));
  }

  Widget _buildTimeline(List<ActivityEntry> entries) {
    final grouped = <DateTime, List<ActivityEntry>>{};
    for (final entry in entries) {
      final date = DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(entry.occurredAt),
      );
      grouped.putIfAbsent(date, () => []).add(entry);
    }

    return CustomScrollView(
      slivers: [
        for (final group in grouped.entries) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _DayHeaderDelegate(date: group.key),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => TimelineTile(entry: group.value[index]),
                childCount: group.value.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({required this.date});

  final DateTime date;

  /// Matches the 16px gutter the tiles below use, so the header and the cards
  /// share one left edge.
  static const double _gutter = 16;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_gutter, 10, _gutter, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            DateFormat.yMMMMEEEEd().format(date),
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) =>
      date != oldDelegate.date;
}
