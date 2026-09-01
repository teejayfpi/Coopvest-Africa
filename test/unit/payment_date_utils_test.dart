import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/utils/payment_date_utils.dart';

void main() {
  group('PaymentDateUtils.daysInMonth', () {
    test('returns 31 for 31-day months', () {
      for (final month in [1, 3, 5, 7, 8, 10, 12]) {
        expect(PaymentDateUtils.daysInMonth(2025, month), 31,
            reason: 'month $month');
      }
    });

    test('returns 30 for 30-day months', () {
      for (final month in [4, 6, 9, 11]) {
        expect(PaymentDateUtils.daysInMonth(2025, month), 30,
            reason: 'month $month');
      }
    });

    test('returns 28 for February in a common year', () {
      expect(PaymentDateUtils.daysInMonth(2025, 2), 28);
      expect(PaymentDateUtils.daysInMonth(2026, 2), 28);
    });

    test('returns 29 for February in a leap year', () {
      expect(PaymentDateUtils.daysInMonth(2024, 2), 29);
      expect(PaymentDateUtils.daysInMonth(2000, 2), 29); // divisible by 400
    });

    test('returns 28 for February in a century non-leap year', () {
      expect(PaymentDateUtils.daysInMonth(1900, 2), 28);
      expect(PaymentDateUtils.daysInMonth(2100, 2), 28);
    });

    test('throws for months outside 1–12', () {
      expect(() => PaymentDateUtils.daysInMonth(2025, 0), throwsArgumentError);
      expect(() => PaymentDateUtils.daysInMonth(2025, 13), throwsArgumentError);
    });
  });

  group('PaymentDateUtils.isValidPaymentDate', () {
    test('accepts every day 1–31 in January', () {
      for (var day = 1; day <= 31; day++) {
        expect(PaymentDateUtils.isValidPaymentDate(2025, 1, day), isTrue,
            reason: 'day $day');
      }
    });

    test('rejects day 31 in 30-day months', () {
      expect(PaymentDateUtils.isValidPaymentDate(2025, 4, 31), isFalse);
      expect(PaymentDateUtils.isValidPaymentDate(2025, 4, 30), isTrue);
    });

    test('rejects day 29 in February of a common year', () {
      expect(PaymentDateUtils.isValidPaymentDate(2025, 2, 29), isFalse);
      expect(PaymentDateUtils.isValidPaymentDate(2025, 2, 28), isTrue);
    });

    test('accepts day 29 in February of a leap year', () {
      expect(PaymentDateUtils.isValidPaymentDate(2024, 2, 29), isTrue);
    });

    test('rejects day 0, negative days, and day 32', () {
      expect(PaymentDateUtils.isValidPaymentDate(2025, 1, 0), isFalse);
      expect(PaymentDateUtils.isValidPaymentDate(2025, 1, -5), isFalse);
      expect(PaymentDateUtils.isValidPaymentDate(2025, 1, 32), isFalse);
    });

    test('rejects invalid months', () {
      expect(PaymentDateUtils.isValidPaymentDate(2025, 0, 15), isFalse);
      expect(PaymentDateUtils.isValidPaymentDate(2025, 13, 15), isFalse);
    });
  });

  group('PaymentDateUtils.validDaysForMonth', () {
    test('returns 1–31 for January', () {
      final days = PaymentDateUtils.validDaysForMonth(2025, 1);
      expect(days.length, 31);
      expect(days.first, 1);
      expect(days.last, 31);
    });

    test('returns 1–28 for February 2025 and 1–29 for February 2024', () {
      expect(PaymentDateUtils.validDaysForMonth(2025, 2).last, 28);
      expect(PaymentDateUtils.validDaysForMonth(2024, 2).last, 29);
    });
  });

  group('PaymentDateUtils.clampDayToMonth', () {
    test('clamps 31 to 30 in April', () {
      expect(PaymentDateUtils.clampDayToMonth(2025, 4, 31), 30);
    });

    test('clamps 31 to 28/29 in February', () {
      expect(PaymentDateUtils.clampDayToMonth(2025, 2, 31), 28);
      expect(PaymentDateUtils.clampDayToMonth(2024, 2, 31), 29);
    });

    test('clamps values below 1 up to 1', () {
      expect(PaymentDateUtils.clampDayToMonth(2025, 1, 0), 1);
      expect(PaymentDateUtils.clampDayToMonth(2025, 1, -10), 1);
    });

    test('keeps valid days unchanged', () {
      expect(PaymentDateUtils.clampDayToMonth(2025, 1, 15), 15);
      expect(PaymentDateUtils.clampDayToMonth(2025, 12, 31), 31);
    });
  });

  group('PaymentDateUtils.resolveDueDate', () {
    test('keeps the preferred day when it exists in the month', () {
      expect(PaymentDateUtils.resolveDueDate(2025, 1, 31),
          DateTime(2025, 1, 31));
      expect(PaymentDateUtils.resolveDueDate(2025, 6, 15),
          DateTime(2025, 6, 15));
    });

    test('falls back to the 30th in 30-day months when the 31st is chosen',
        () {
      expect(PaymentDateUtils.resolveDueDate(2025, 4, 31),
          DateTime(2025, 4, 30));
      expect(PaymentDateUtils.resolveDueDate(2025, 9, 31),
          DateTime(2025, 9, 30));
    });

    test('falls back to the last day of February when day 29–31 is chosen',
        () {
      expect(PaymentDateUtils.resolveDueDate(2025, 2, 31),
          DateTime(2025, 2, 28));
      expect(PaymentDateUtils.resolveDueDate(2025, 2, 29),
          DateTime(2025, 2, 28));
      expect(PaymentDateUtils.resolveDueDate(2024, 2, 31),
          DateTime(2024, 2, 29)); // leap year
    });

    test('never rolls over into the following month', () {
      for (final month in [2, 4, 6, 9, 11]) {
        final due = PaymentDateUtils.resolveDueDate(2025, month, 31);
        expect(due.month, month, reason: 'month $month');
        expect(due.day, PaymentDateUtils.daysInMonth(2025, month));
      }
    });
  });
}
