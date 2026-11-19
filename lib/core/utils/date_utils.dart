import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _displayDateTimeFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  /// Formats date to 'YYYY-MM-DD'
  static String formatDateIso(DateTime date) {
    return _isoDateFormat.format(date);
  }

  /// Parses date from 'YYYY-MM-DD'
  static DateTime parseDateIso(String dateStr) {
    return _isoDateFormat.parse(dateStr);
  }

  /// Formats date for display: 'Mar 15, 2026'
  static String formatDisplayDate(DateTime date) {
    return _displayDateFormat.format(date);
  }

  /// Formats time: '09:30 AM'
  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }

  /// Formats date & time: 'Mar 15, 2026 • 09:30 AM'
  static String formatDateTime(DateTime dateTime) {
    return _displayDateTimeFormat.format(dateTime);
  }

  /// Formats duration to 'Xh Ym Zs' or 'Xh Ym'
  static String formatDuration(Duration duration, {bool includeSeconds = true}) {
    if (duration.isNegative) return '0h 0m 0s';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (includeSeconds) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  /// Calculates total calendar days between start and end date inclusive.
  /// Ignores weekends and holidays as per assignment spec.
  static int calculateLeaveDays(DateTime start, DateTime end) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    if (endDay.isBefore(startDay)) return 0;
    return endDay.difference(startDay).inDays + 1;
  }

  /// Returns true if two date ranges overlap (both ranges inclusive)
  static bool areRangesOverlapping(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    final aStart = DateTime(startA.year, startA.month, startA.day);
    final aEnd = DateTime(endA.year, endA.month, endA.day);
    final bStart = DateTime(startB.year, startB.month, startB.day);
    final bEnd = DateTime(endB.year, endB.month, endB.day);

    return !(aEnd.isBefore(bStart) || aStart.isAfter(bEnd));
  }
}
