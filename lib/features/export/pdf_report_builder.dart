import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:todo/features/tasks/domain/activity_action.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

class ActivityReportSummary {
  const ActivityReportSummary({
    required this.created,
    required this.completed,
    required this.deleted,
    required this.completionRate,
    required this.busiestDay,
    required this.categoryActivityCounts,
  });

  final int created;
  final int completed;
  final int deleted;
  final double completionRate;
  final DateTime? busiestDay;
  final Map<String, int> categoryActivityCounts;
}

class PdfReportBuilder {
  const PdfReportBuilder();

  static ActivityReportSummary summarize(List<ActivityEntry> activities) {
    var created = 0;
    var completed = 0;
    var deleted = 0;
    final createdOrCompletedTaskIds = <String>{};
    final completedTaskIds = <String>{};
    final activityCountsByDay = <DateTime, int>{};
    final categoryActivityCounts = <String, int>{};

    for (final entry in activities) {
      final action = ActivityActionX.fromValue(entry.action);
      final taskKey = entry.taskId ?? 'entry-${entry.id}';
      if (action == ActivityAction.created) {
        created++;
        createdOrCompletedTaskIds.add(taskKey);
      } else if (action == ActivityAction.completed) {
        completed++;
        createdOrCompletedTaskIds.add(taskKey);
        completedTaskIds.add(taskKey);
      } else if (action == ActivityAction.deleted) {
        deleted++;
      }

      final occurredAt = DateTime.fromMillisecondsSinceEpoch(entry.occurredAt);
      final day = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
      activityCountsByDay.update(day, (count) => count + 1, ifAbsent: () => 1);
      categoryActivityCounts.update(
        entry.categoryName ?? 'Uncategorized',
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    DateTime? busiestDay;
    var busiestDayCount = 0;
    for (final entry in activityCountsByDay.entries) {
      if (entry.value > busiestDayCount) {
        busiestDay = entry.key;
        busiestDayCount = entry.value;
      }
    }
    final completionRate = createdOrCompletedTaskIds.isEmpty
        ? 0.0
        : completedTaskIds.intersection(createdOrCompletedTaskIds).length /
              createdOrCompletedTaskIds.length;

    return ActivityReportSummary(
      created: created,
      completed: completed,
      deleted: deleted,
      completionRate: completionRate,
      busiestDay: busiestDay,
      categoryActivityCounts: categoryActivityCounts,
    );
  }

  Future<Uint8List> build({
    required String appName,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<ActivityEntry> activities,
    DateTime? generatedAt,
    bool includeTaskAppendix = false,
    Uint8List? regularFontBytes,
    Uint8List? semiboldFontBytes,
  }) async {
    if ((regularFontBytes == null) != (semiboldFontBytes == null)) {
      throw ArgumentError(
        'Both regular and semibold font bytes must be provided together.',
      );
    }

    final document = pw.Document();
    final generated = generatedAt ?? DateTime.now();
    final dateFormat = DateFormat.yMMMd();
    final dateTimeFormat = DateFormat.yMMMd().add_jm();
    final summary = summarize(activities);
    final theme = regularFontBytes == null
        ? pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          )
        : pw.ThemeData.withFont(
            base: pw.Font.ttf(ByteData.sublistView(regularFontBytes)),
            bold: pw.Font.ttf(ByteData.sublistView(semiboldFontBytes!)),
          );
    final categories = summary.categoryActivityCounts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final largestCategoryCount = categories.isEmpty
        ? 0
        : categories.first.value;
    final summaryRows = [
      ('Created', summary.created.toString()),
      ('Completed', summary.completed.toString()),
      ('Deleted', summary.deleted.toString()),
      (
        'Completion rate',
        NumberFormat.percentPattern().format(summary.completionRate),
      ),
      (
        'Busiest day',
        summary.busiestDay == null
            ? 'No activity'
            : dateFormat.format(summary.busiestDay!),
      ),
    ];
    final activityRows = activities.map((entry) {
      return [
        dateTimeFormat.format(
          DateTime.fromMillisecondsSinceEpoch(entry.occurredAt),
        ),
        ActivityActionX.fromValue(entry.action),
        entry.taskTitle,
        _activityChange(entry),
      ];
    }).toList();
    final appendixGroups = <String, List<ActivityEntry>>{};
    if (includeTaskAppendix) {
      for (final entry in activities) {
        appendixGroups
            .putIfAbsent(entry.taskId ?? entry.taskTitle, () => [])
            .add(entry);
      }
    }

    document.addPage(
      pw.MultiPage(
        maxPages: 100,
        theme: theme,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated offline on-device',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (context) => [
          pw.Text(
            appName,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Activity report',
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '${dateFormat.format(rangeStart)} to ${dateFormat.format(rangeEnd)}',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated ${dateTimeFormat.format(generated)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Text(
            '${activities.length} activities recorded',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          for (final row in summaryRows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text(row.$1)),
                  pw.Text(row.$2),
                ],
              ),
            ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Activity by category',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          if (categories.isEmpty)
            pw.Text('No category activity')
          else
            for (final category in categories)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 5),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 110,
                      child: pw.Text(
                        category.key,
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      width: 260 * category.value / largestCategoryCount,
                      height: 8,
                      color: PdfColors.deepPurple,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(category.value.toString()),
                  ],
                ),
              ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Activity log',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Action', 'Task', 'Change'],
            data: activityRows,
            headerHeight: 24,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.deepPurple,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColors.grey300,
                width: 0.5,
              ),
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(82),
              1: const pw.FixedColumnWidth(90),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            cellFormat: (index, cell) =>
                cell is ActivityAction ? cell.label : cell.toString(),
            cellBuilder: (index, cell, rowNum) {
              if (index != 1 || cell is! ActivityAction) return null;
              return pw.Text(
                cell.label,
                style: pw.TextStyle(
                  color: _actionColor(cell),
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              );
            },
          ),
          if (appendixGroups.isNotEmpty) ...[
            pw.NewPage(),
            pw.Text(
              'Per-task appendix',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            for (final group in appendixGroups.entries) ...[
              pw.Text(
                group.value.first.taskTitle,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              for (final entry in group.value)
                pw.Bullet(
                  text:
                      '${ActivityActionX.fromValue(entry.action).label} - '
                      '${dateTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(entry.occurredAt))}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              pw.SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );

    return document.save();
  }

  static String _activityChange(ActivityEntry entry) {
    if (entry.oldValue == null && entry.newValue == null) return '';
    return '${entry.oldValue ?? '-'} -> ${entry.newValue ?? '-'}';
  }

  static PdfColor _actionColor(ActivityAction action) {
    return switch (action) {
      ActivityAction.completed ||
      ActivityAction.restored ||
      ActivityAction.subtaskCompleted => PdfColors.green,
      ActivityAction.deleted || ActivityAction.subtaskDeleted => PdfColors.red,
      ActivityAction.reminderSet ||
      ActivityAction.reminderCleared => PdfColors.orange,
      _ => PdfColors.blue,
    };
  }
}
