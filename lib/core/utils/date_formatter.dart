import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dayMonthYear = DateFormat('d MMM yyyy', 'th_TH');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'th_TH');
  static final DateFormat _fullDateTime = DateFormat('d MMMM yyyy, HH:mm น.', 'th_TH');
  static final DateFormat _timeOnly = DateFormat('HH:mm น.');

  static String formatDayMonthYear(DateTime dateTime) {
    return _dayMonthYear.format(dateTime);
  }

  static String formatMonthYear(DateTime dateTime) {
    return _monthYear.format(dateTime);
  }

  static String formatFullDateTime(DateTime dateTime) {
    return _fullDateTime.format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return _timeOnly.format(dateTime);
  }

  static String formatSmartDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (checkDate == today) {
      return 'วันนี้';
    } else if (checkDate == yesterday) {
      return 'เมื่อวาน';
    } else {
      return formatDayMonthYear(dateTime);
    }
  }

  static String formatSmartMonth(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.year == now.year && dateTime.month == now.month) {
      return 'เดือนนี้';
    }
    return formatMonthYear(dateTime);
  }
}
