import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/presentation/providers/wallet_provider.dart';
import 'package:coopvest_mobile/presentation/widgets/advance_payment_card.dart';

/// The wallet's "pay ahead" entry point.
///
/// It exists because the obligations card returns an "all caught up" state when
/// nothing is due, which is exactly when a member is most likely to pay a month
/// in advance. The first test pins that: the card must render even when every
/// current-month figure is zero.
void main() {
  const surface = Size(1200, 1600);

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
            body: SingleChildScrollView(child: AdvancePaymentCard()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// A member who has already paid this month: nothing is due now.
  Map<String, dynamic> paidUp({Map<String, dynamic>? advance}) => {
        'monthly_savings': 5000,
        'loans': const [],
        'fines': const [],
        'fees': const [],
        'month_paid_savings': true,
        'joined_this_month': false,
        'current_month': '2026-02',
        'savings_due': 0,
        'administrative_fee_due': 0,
        'total_due': 0,
        'advance': advance ??
            {
              'month': '2026-03',
              'savings': 5000,
              'administrative_fee': 1500,
              'loans': const [],
              'fines': const [],
              'total': 6500,
            },
      };

  testWidgets('is offered to a member who has already paid this month',
      (tester) async {
    await pumpCard(tester, paidUp());

    expect(find.text('Pay ahead'), findsOneWidget);
    expect(find.textContaining('March 2026'), findsWidgets);
    expect(find.textContaining('6,500'), findsWidgets);
  });

  testWidgets('states the administrative fee when one is charged',
      (tester) async {
    await pumpCard(tester, paidUp());

    expect(find.textContaining('1,500 administrative fee'), findsOneWidget);
  });

  testWidgets('omits the fee line and explains the salary deduction when exempt',
      (tester) async {
    await pumpCard(
      tester,
      paidUp(advance: {
        'month': '2026-03',
        'savings': 5000,
        'administrative_fee': 0,
        'loans': const [],
        'fines': const [],
        'total': 5000,
      }),
    );

    expect(find.textContaining('administrative fee'), findsOneWidget);
    expect(find.textContaining('deducted from salary'), findsOneWidget);
  });

  testWidgets('includes outstanding fines so they are not left behind',
      (tester) async {
    await pumpCard(
      tester,
      paidUp(advance: {
        'month': '2026-03',
        'savings': 5000,
        'administrative_fee': 1500,
        'loans': const [],
        'fines': [
          {'id': 'fine-1', 'label': 'Late Repayment Fine', 'amount': 3000},
        ],
        'total': 9500,
      }),
    );

    expect(find.textContaining('9,500'), findsWidgets);
    expect(find.textContaining('3,000 in outstanding fines'), findsOneWidget);
  });

  testWidgets('renders nothing when there is no month to pay for',
      (tester) async {
    await pumpCard(tester, {
      'monthly_savings': 5000,
      'loans': const [],
      'fines': const [],
      'fees': const [],
      'month_paid_savings': true,
      'current_month': '2026-02',
      'advance': const {},
    });

    expect(find.text('Pay ahead'), findsNothing);
  });
}
