/// Utilities for validating preferred payment dates against the actual
/// number of days in each month, including leap-year handling for February.
library;

class PaymentDateUtils {
  PaymentDateUtils._();

  static const List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static bool isLeapYear(int year) {
    if (year % 4 != 0) return false;
    if (year % 100 != 0) return true;
    return year % 400 == 0;
  }

  /// Returns the number of days in [month] (1–12) of [year].
  ///
  /// Throws [ArgumentError] when [month] is outside 1–12.
  static int daysInMonth(int year, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12');
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && isLeapYear(year)) return 29;
    return days[month - 1];
  }

  /// Whether [day] exists in [month] of [year].
  static bool isValidPaymentDate(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    return day >= 1 && day <= daysInMonth(year, month);
  }

  /// The list of selectable days (1-based) for [month] of [year].
  static List<int> validDaysForMonth(int year, int month) {
    return List<int>.generate(daysInMonth(year, month), (i) => i + 1);
  }

  /// Clamps [day] to the last valid day of [month] when it does not exist
  /// there (e.g. 31 → 30 for April, 31 → 28/29 for February).
  static int clampDayToMonth(int year, int month, int day) {
    final max = daysInMonth(year, month);
    if (day < 1) return 1;
    if (day > max) return max;
    return day;
  }

  /// Resolves the actual payment due date for a recurring preferred [day]
  /// in [month] of [year].
  ///
  /// A preferred day of 29–31 does not exist in every month, so the due
  /// date falls back to the last day of that month: the 31st becomes the
  /// 30th in April and the 28th/29th in February. The payment therefore
  /// always lands within the intended month instead of silently rolling
  /// into the next one.
  static DateTime resolveDueDate(int year, int month, int day) {
    return DateTime(year, month, clampDayToMonth(year, month, day));
  }

  /// Member-facing explanation shown when a preferred day of 29–31 is
  /// selected, so the last-day-of-month fallback is never a surprise.
  static const String endOfMonthFallbackHint =
      'If a month does not have this day, your payment will be made on the last day of that month.';
}
