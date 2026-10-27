import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/export/pdf_report_builder.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';

void main() {
  test('builds a PDF cover from report data without database access', () async {
    final bytes = await const PdfReportBuilder().build(
      appName: 'Todo',
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2026, 1, 31),
      generatedAt: DateTime(2026, 2, 1, 12),
      activities: const [
        ActivityEntry(
          id: 1,
          taskTitle: 'Example task',
          action: 0,
          occurredAt: 1767225600000,
        ),
      ],
    );

    expect(bytes.length, greaterThan(100));
    expect(bytes.sublist(0, 5), [37, 80, 68, 70, 45]);
  });
}
