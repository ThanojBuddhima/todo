import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:todo/features/export/pdf_report_builder.dart';
import 'package:todo/features/tasks/data/activity_dao.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

class ExportService {
  ExportService({
    ActivityDao? activityDao,
    PdfReportBuilder? reportBuilder,
    DocumentsDirectoryProvider? documentsDirectory,
    DateTime Function()? clock,
  }) : _activityDao = activityDao ?? ActivityDao(),
       _reportBuilder = reportBuilder ?? const PdfReportBuilder(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final ActivityDao _activityDao;
  final PdfReportBuilder _reportBuilder;
  final DocumentsDirectoryProvider _documentsDirectory;
  final DateTime Function() _clock;

  Future<File> exportReport({
    required String appName,
    required DateTime startDate,
    required DateTime endDate,
    bool includeTaskAppendix = false,
    Set<String>? categoryNames,
    Set<int>? actionValues,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) {
      throw ArgumentError(
        'The report end date must not precede its start date.',
      );
    }
    final endExclusive = end.add(const Duration(days: 1));
    final queriedActivities = await _activityDao.getInRange(
      startAtInclusive: start.millisecondsSinceEpoch,
      endAtExclusive: endExclusive.millisecondsSinceEpoch,
    );
    final activities = queriedActivities.where((entry) {
      final matchesCategory =
          categoryNames == null ||
          categoryNames.contains(entry.categoryName ?? 'Uncategorized');
      final matchesAction =
          actionValues == null || actionValues.contains(entry.action);
      return matchesCategory && matchesAction;
    }).toList();
    final generatedAt = _clock();
    final regularFontBytes = await _loadFont('assets/fonts/Inter-Regular.ttf');
    final semiboldFontBytes = await _loadFont(
      'assets/fonts/Inter-SemiBold.ttf',
    );
    final bytes = await _reportBuilder.build(
      appName: appName,
      rangeStart: start,
      rangeEnd: end,
      activities: activities,
      generatedAt: generatedAt,
      includeTaskAppendix: includeTaskAppendix,
      regularFontBytes: regularFontBytes,
      semiboldFontBytes: semiboldFontBytes,
    );

    final directory = await _documentsDirectory();
    await directory.create(recursive: true);
    final fileName =
        'activity-report-${DateFormat('yyyyMMdd-HHmm').format(generatedAt)}.pdf';
    final file = File(path.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> _loadFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
