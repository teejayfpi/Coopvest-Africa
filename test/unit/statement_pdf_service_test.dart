import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/services/statement_pdf_service.dart';
import 'package:coopvest_mobile/data/models/auth_models.dart';
import 'package:coopvest_mobile/data/models/wallet_models.dart';

/// These tests pin down the two things that made the previous statement look
/// unprofessional, plus the glyph trap that is invisible until a member opens
/// the PDF.
///
/// The `pdf` package's built-in fonts encode text as Latin-1 and silently draw
/// a blank placeholder for anything outside it. A Naira sign therefore prints
/// as an empty gap on the most important figure in the document, so the service
/// writes `NGN`. The assertions below are what stop that regressing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Transaction txn({
    required double amount,
    String type = 'deposit',
    String? category,
    String status = 'completed',
    String? description,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime(2026, 3, 15, 10);
    return Transaction(
      id: 't-${type.hashCode}-$amount',
      walletId: 'w1',
      type: type,
      category: category ?? (amount >= 0 ? 'credit' : 'debit'),
      amount: amount,
      status: status,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  Wallet wallet({double balance = 0, double available = 0}) => Wallet(
        id: 'w1',
        userId: 'u1',
        balance: balance,
        totalContributions: 0,
        totalSavings: 0,
        monthlySavings: 0,
        pendingContributions: 0,
        availableForWithdrawal: available,
        updatedAt: DateTime(2026, 3, 15),
      );

  group('currency is written in a glyph the PDF font can draw', () {
    test('money() uses the NGN code and stays inside Latin-1', () {
      expect(StatementPdfService.money(1234.5), 'NGN 1,234.50');
      expect(StatementPdfService.money(0), 'NGN 0.00');
      expect(StatementPdfService.money(1234567.89), 'NGN 1,234,567.89');

      // The whole point: every character must be encodable, or the built-in
      // font replaces it with blank space.
      expect(() => latin1.encode(StatementPdfService.money(1234.5)),
          returnsNormally);
    });

    test('the Naira sign itself is NOT drawable, which is why NGN is used', () {
      // 0x20A6 is outside Latin-1. If this ever starts passing, the constraint
      // has changed and the currency code could be revisited.
      expect(() => latin1.encode('\u20A6'), throwsA(isA<ArgumentError>()));
      expect(StatementPdfService.money(10), isNot(contains('\u20A6')));
    });

    test('signedMoney() marks credits and debits', () {
      expect(StatementPdfService.signedMoney(500), '+NGN 500.00');
      expect(StatementPdfService.signedMoney(-500), '-NGN 500.00');
    });

    test('type labels are human readable and Latin-1 safe', () {
      expect(StatementPdfService.typeLabel('loan_repayment'), 'Loan Repayment');
      expect(StatementPdfService.typeLabel('transfer_in'), 'Transfer In');
      expect(StatementPdfService.typeLabel('deposit'), 'Deposit');
      expect(StatementPdfService.typeLabel(''), 'Transaction');
      expect(
        () => latin1.encode(StatementPdfService.typeLabel('loan_repayment')),
        returnsNormally,
      );
    });

    test('statement type labels cover each selection', () {
      expect(StatementPdfService.statementTypeLabel('all'),
          'Complete Account Statement');
      expect(StatementPdfService.statementTypeLabel('contributions'),
          'Contributions Statement');
      expect(StatementPdfService.statementTypeLabel('loans'),
          'Loans Statement');
      expect(StatementPdfService.statementTypeLabel('transactions'),
          'Transaction History');
    });
  });

  group('opening balance is derived from the movements shown', () {
    test('a credit-heavy period means the opening balance was lower', () {
      final transactions = [
        txn(amount: 5000), // credit
        txn(amount: 2000), // credit
      ];
      // Closing is 6000, so the account opened at 6000 - 5000 - 2000 = -1000.
      expect(
        StatementPdfService.openingBalance(wallet(balance: 6000), transactions),
        -1000,
      );
    });

    test('a debit-heavy period means the opening balance was higher', () {
      final transactions = [
        txn(amount: -1500, category: 'debit'),
        txn(amount: -500, category: 'debit'),
      ];
      // Closing is 3000, so it opened at 3000 + 1500 + 500 = 5000.
      expect(
        StatementPdfService.openingBalance(wallet(balance: 3000), transactions),
        5000,
      );
    });

    test('no transactions means opening equals closing', () {
      expect(StatementPdfService.openingBalance(wallet(balance: 750), []), 750);
    });

    test('the opening and closing figures reconcile with the row totals', () {
      final transactions = [
        txn(amount: 4000),
        txn(amount: -1000, category: 'debit'),
        txn(amount: 250),
      ];
      final opening =
          StatementPdfService.openingBalance(wallet(balance: 3250), transactions);
      final credits = transactions
          .where((t) => t.isCredit)
          .fold<double>(0, (s, t) => s + t.amount.abs());
      final debits = transactions
          .where((t) => !t.isCredit)
          .fold<double>(0, (s, t) => s + t.amount.abs());
      expect(opening + credits - debits, 3250);
    });
  });

  group('the document builds', () {
    test('a populated statement produces a real PDF', () async {
      final transactions = [
        txn(amount: 25000, description: 'Monthly contribution'),
        txn(amount: -7500, type: 'withdrawal', category: 'debit'),
        txn(amount: 1200.5, type: 'interest'),
      ];

      final doc = await StatementPdfService().build(
        user: User(
          id: 'u1',
          email: 'member@example.com',
          name: 'Test Member',
          phone: '+2348012345678',
          kycStatus: 'approved',
          membershipStatus: 'active',
          isEmailVerified: true,
          registrationCompleted: true,
          registrationFeePaid: true,
          createdAt: DateTime(2025, 1, 15),
        ),
        transactions: transactions,
        wallet: wallet(balance: 18700.5, available: 15000),
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        statementType: 'all',
      );

      final bytes = await doc.save();
      expect(bytes.length, greaterThan(1000));
      // A PDF always opens with the %PDF marker.
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('an empty period still renders a valid document', () async {
      final doc = await StatementPdfService().build(
        user: null,
        transactions: const [],
        wallet: null,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        statementType: 'loans',
      );
      final bytes = await doc.save();
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('a long statement paginates without throwing', () async {
      final transactions = List.generate(
        120,
        (i) => txn(
          amount: i.isEven ? 1000.0 + i : -500.0 - i,
          category: i.isEven ? 'credit' : 'debit',
          description: 'Transaction number $i',
          createdAt: DateTime(2026, 3, 1).add(Duration(hours: i)),
        ),
      );

      final doc = await StatementPdfService().build(
        user: null,
        transactions: transactions,
        wallet: wallet(balance: 10000),
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        statementType: 'all',
      );

      final bytes = await doc.save();
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
