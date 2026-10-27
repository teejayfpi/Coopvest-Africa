import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/presentation/providers/wallet_provider.dart';
import 'package:coopvest_mobile/presentation/widgets/obligations_card.dart';

/// Regression coverage for the reported "fee not included in the payment" bug.
///
/// The obligations card listed fines and fees in its rows and counted them in
/// "Total due this month", but the amount it actually handed to the deposit
/// screen was `hasLoanObligation ? loan : savings` — the fee was dropped, so a
/// member with a ₦5,000 contribution and a ₦1,500 fee was charged ₦5,000.
///
/// These assert the two figures agree: what the card says is due and what the
/// Pay Now button will charge.
void main() {
  const surface = Size(1200, 1400);

  Future<void> pumpCard(
    WidgetTester tester,
    Map<String, dynamic> obligations,
  ) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          obligationsProvider.overrideWith((ref) async => obligations),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ObligationsCard()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Map<String, dynamic> base({
    double monthlySavings = 5000,
    List<Map<String, dynamic>> loans = const [],
    List<Map<String, dynamic>> fines = const [],
    List<Map<String, dynamic>> fees = const [],
  }) {
    return {
      'monthly_savings': monthlySavings,
      'loans': loans,
      'fines': fines,
      'fees': fees,
      'month_paid_savings': false,
      'joined_this_month': false,
      'current_month': '2026-02',
    };
  }

  testWidgets('an outstanding fee is included in the amount payable',
      (tester) async {
    await pumpCard(
      tester,
      base(
        monthlySavings: 5000,
        fees: [
          {'id': 'fee-1', 'label': 'Administrative Fee', 'amount': 1500},
        ],
      ),
    );

    // The card must charge the total due (5,000 + 1,500), not just the savings.
    expect(find.text('₦6,500'), findsWidgets,
        reason: 'the fee must be added to the amount payable');
    expect(
      find.textContaining('Pays ₦6,500'),
      findsOneWidget,
      reason: 'the Pay Now caption must match the charge',
    );
  });

  testWidgets('a fine is included in the amount payable', (tester) async {
    await pumpCard(
      tester,
      base(
        monthlySavings: 5000,
        fines: [
          {'id': 'fine-1', 'label': 'Late Repayment', 'amount': 3000},
        ],
      ),
    );

    expect(find.text('₦8,000'), findsWidgets);
    expect(find.textContaining('Pays ₦8,000'), findsOneWidget);
  });

  testWidgets('savings and a loan repayment are summed together',
      (tester) async {
    await pumpCard(
      tester,
      base(
        monthlySavings: 5000,
        loans: [
          {
            'loan_id': 'L1',
            'monthly_repayment': 4000,
            'remaining_balance': 20000,
            'status': 'active',
          },
        ],
      ),
    );

    expect(find.text('₦9,000'), findsWidgets);
    expect(find.textContaining('Pays ₦9,000'), findsOneWidget);
  });

  testWidgets('all caught up when nothing is due', (tester) async {
    await pumpCard(tester, base(monthlySavings: 0));

    expect(find.textContaining('caught up'), findsOneWidget);
    expect(find.text('Pay Now'), findsNothing);
  });
}
