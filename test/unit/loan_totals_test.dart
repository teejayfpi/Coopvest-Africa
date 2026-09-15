import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/loan_models.dart';

/// Regression tests for the loan dashboard totals.
///
/// "Total Repaid" previously summed `totalRepayment - remainingBalance` over
/// every loan, including cancelled applications. A cancelled loan has a NULL
/// remaining_balance (parsed as 0), so it counted its full repayment figure as
/// "repaid" — inflating the member's total by money that never existed.
void main() {
  group('isLoanNeverDisbursed', () {
    test('flags cancelled and rejected applications', () {
      expect(isLoanNeverDisbursed('cancelled'), isTrue);
      expect(isLoanNeverDisbursed('canceled'), isTrue);
      expect(isLoanNeverDisbursed('rejected'), isTrue);
      expect(isLoanNeverDisbursed('declined'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isLoanNeverDisbursed('Cancelled'), isTrue);
      expect(isLoanNeverDisbursed('REJECTED'), isTrue);
    });

    test('does not flag loans that were actually disbursed', () {
      expect(isLoanNeverDisbursed('active'), isFalse);
      expect(isLoanNeverDisbursed('repaying'), isFalse);
      expect(isLoanNeverDisbursed('approved'), isFalse);
      expect(isLoanNeverDisbursed('completed'), isFalse);
      expect(isLoanNeverDisbursed('overdue'), isFalse);
    });
  });

  group('loan totals exclude never-disbursed loans', () {
    // Minimal factory for the fields the totals touch.
    Loan loan({
      required String status,
      required double amount,
      required double totalRepayment,
      required double remainingBalance,
    }) {
      return Loan(
        id: 'LN-$status-$amount',
        userId: 'u1',
        type: 'Quick Loan',
        amount: amount,
        tenure: 6,
        interestRate: 7.5,
        monthlyRepayment: 0,
        totalRepayment: totalRepayment,
        status: status,
        purpose: '',
        guarantorsAccepted: 0,
        guarantorsRequired: 3,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        remainingBalance: remainingBalance,
      );
    }

    final loans = [
      // A real loan, partly repaid.
      loan(status: 'active', amount: 100000, totalRepayment: 107500, remainingBalance: 50000),
      // Two cancelled applications — never disbursed.
      loan(status: 'cancelled', amount: 500000, totalRepayment: 595000, remainingBalance: 0),
      loan(status: 'cancelled', amount: 80000, totalRepayment: 84000, remainingBalance: 0),
    ];

    test('total borrowed counts only disbursed loans', () {
      final total = loans
          .where((l) => !isLoanNeverDisbursed(l.status))
          .fold<double>(0, (s, l) => s + l.amount);
      expect(total, 100000);
    });

    test('total repaid excludes cancelled loans', () {
      final total = loans
          .where((l) => !isLoanNeverDisbursed(l.status))
          .fold<double>(0, (s, l) => s + l.amountRepaid);
      // 107500 - 50000 = 57500, and NOT the extra 595000 + 84000 from cancelled.
      expect(total, 57500);
    });
  });
}
