import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/presentation/providers/wallet_provider.dart';
import 'package:coopvest_mobile/presentation/widgets/obligations_card.dart';

/// Coverage for the "pay a month in advance" offer.
///
/// Two things must hold. A fine is owed now whatever month is being paid for,
/// so it belongs in the offer — leaving it out let a member clear a future month
/// and still owe money they already had. And an exempt member's employer
/// withholds the administrative fee from pay, so the offer must not charge it
/// a second time.
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
            body: SingleChildScrollView(child: ObligationsCard()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Map<String, dynamic> base({
    Map<String, dynamic>? advance,
    List<Map<String, dynamic>> fines = const [],
  }) {
    return {
      'monthly_savings': 5000,
      'loans': const [],
      'fines': fines,
      'fees': const [],
      'month_paid_savings': false,
      'joined_this_month': false,
      'current_month': '2026-02',
      if (advance != null) 'advance': advance,
    };
  }

  testWidgets('the advance offer includes the administrative fee for a payer',
      (tester) async {
    await pumpCard(
      tester,
      base(
        advance: {
          'month': '2026-03',
          'savings': 5000,
          'administrative_fee': 1500,
          'total': 6500,
        },
      ),
    );

    expect(find.textContaining('Pay March 2026 in advance'), findsOneWidget);
    expect(find.textContaining('₦6,500'), findsWidgets);
    expect(
      find.textContaining('₦1,500 administrative fee'),
      findsOneWidget,
      reason: 'a paying member must see the fee in the offer',
    );
  });

  testWidgets('an exempt member is not charged the fee in the advance offer',
      (tester) async {
    await pumpCard(
      tester,
      base(
        advance: {
          'month': '2026-03',
          'savings': 5000,
          'administrative_fee': 0,
          'total': 5000,
        },
      ),
    );

    // No priced fee line, and no "₦0 administrative fee" either — that reads as
    // a charge of zero rather than as withheld from salary. The caption does
    // mention the fee, to say why it is absent.
    expect(find.textContaining('₦0 administrative fee'), findsNothing);
    expect(find.textContaining('₦1,500 administrative fee'), findsNothing);
    expect(
      find.textContaining('deducted from salary'),
      findsOneWidget,
      reason: 'the offer must say why the fee is absent',
    );
    expect(find.textContaining('₦5,000'), findsWidgets);
  });

  testWidgets('outstanding fines are added to the advance offer',
      (tester) async {
    await pumpCard(
      tester,
      base(
        advance: {
          'month': '2026-03',
          'savings': 5000,
          'administrative_fee': 1500,
          'fines': [
            {'id': 'fine-1', 'label': 'Late Repayment', 'amount': 3000},
          ],
          'fines_total': 3000,
          'total': 9500,
        },
      ),
    );

    expect(
      find.textContaining('₦3,000 in outstanding fines'),
      findsOneWidget,
      reason: 'a fine is owed now, so it belongs in the advance total',
    );
    expect(find.textContaining('₦9,500'), findsWidgets);
  });

  testWidgets('without a server total, fines still reach the computed offer',
      (tester) async {
    // The card falls back to savings + fee + fines when the backend omits
    // `total`. That fallback is the branch a client/server version skew hits,
    // so it must price fines too.
    await pumpCard(
      tester,
      base(
        advance: {
          'month': '2026-03',
          'savings': 5000,
          'administrative_fee': 1500,
          'fines': [
            {'id': 'fine-1', 'label': 'Late Repayment', 'amount': 3000},
          ],
        },
      ),
    );

    expect(find.textContaining('₦9,500'), findsWidgets,
        reason: 'the fallback total must include the fine');
  });

  testWidgets('without a server total, an exempt offer omits the fee',
      (tester) async {
    await pumpCard(
      tester,
      base(
        advance: {
          'month': '2026-03',
          'savings': 5000,
          'administrative_fee': 0,
        },
      ),
    );

    expect(find.textContaining('₦5,000'), findsWidgets);
    expect(find.textContaining('₦6,500'), findsNothing,
        reason: 'the fallback must not add a fee the member is exempt from');
  });

  testWidgets('the offer is not shown when no month is priced', (tester) async {
    await pumpCard(tester, base());

    expect(find.textContaining('in advance'), findsNothing);
  });

  testWidgets('a zero-amount fine is not listed in the offer', (tester) async {
    await pumpCard(
      tester,
      base(
        advance: {
          'month': '2026-03',
          'savings': 5000,
          'administrative_fee': 1500,
          'fines': [
            {'id': 'fine-1', 'label': 'Late Repayment', 'amount': 0},
          ],
          'total': 6500,
        },
      ),
    );

    expect(find.textContaining('outstanding fines'), findsNothing);
  });
}
