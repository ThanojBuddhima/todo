import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:todo/features/tasks/domain/activity_entry.dart';

class PdfReportBuilder {
  const PdfReportBuilder();

  Future<Uint8List> build({
    required String appName,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<ActivityEntry> activities,
    DateTime? generatedAt,
  }) async {
    final document = pw.Document();
    final generated = generatedAt ?? DateTime.now();
    final dateFormat = DateFormat.yMMMd();
    final dateTimeFormat = DateFormat.yMMMd().add_jm();

    document.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            appName,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Activity report',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
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
        ],
      ),
    );

    return document.save();
  }
}
