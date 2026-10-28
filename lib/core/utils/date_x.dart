import 'package:intl/intl.dart';

class DateX {
  static String formatDateDay(DateTime date) =>
      DateFormat('EEE, MMM d').format(date);
  static String formatDateTime(DateTime date) =>
      DateFormat('MMM d, y h:mm a').format(date);

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
