import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:coopvest_mobile/data/repositories/auth_repository.dart';
import 'package:coopvest_mobile/data/api/loan_api_service.dart';
import 'package:coopvest_mobile/data/models/loan_models.dart';
import 'package:coopvest_mobile/presentation/providers/loan_provider.dart';
import 'package:coopvest_mobile/presentation/screens/loan/loan_details_screen.dart';

/// Regression coverage for the reported header-card overflow: Loan ID, Amount
/// and Tenure sat in an unconstrained Row, so the 36-character UUID pushed
/// Amount and Tenure off the right edge. The card now shows the short reference
/// and every item is Expanded, so the row cannot overflow even with the fallback
/// UUID-derived reference.
void main() {
  const narrow = Size(320, 640);

  Loan sampleLoan({String id = 'c6ffa8c2-37e4-4c0c-9f4c-25c8505a4a1c', String reference = ''}) {
    return Loan(
      id: id,
      reference: reference,
      userId: 'u1',
      type: 'Personal Loan',
      amount: 500000,
      tenure: 12,
      interestRate: 5,
      monthlyRepayment: 45000,
      totalRepayment: 540000,
      status: 'pending',
      guarantorsAccepted: 0,
      guarantorsRequired: 3,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, Loan loan) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loanProvider.overrideWith(
            (ref) => _StubLoanNotifier(LoansState(loans: [loan])),
          ),
          loanGuarantorsProvider.overrideWith((ref, arg) async => <GuarantorData>[]),
          loanRepaymentScheduleProvider
              .overrideWith(
            (ref, arg) async => RepaymentScheduleData(
              installments: const [],
              totalInterest: 0,
              totalPrincipal: 0,
            ),
          ),
        ],
        child: MaterialApp(home: LoanDetailsScreen(loanId: loan.id)),
      ),
    );
    await tester.pump();
  }

  testWidgets('header card shows the reference and does not overflow',
      (tester) async {
    await pumpScreen(tester, sampleLoan(reference: 'LN-1789968194496-582'));

    expect(tester.takeException(), isNull);
    expect(find.text('LN-1789968194496-582'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Tenure'), findsOneWidget);
  });

  testWidgets('survives a loan with no reference (UUID fallback)',
      (tester) async {
    await pumpScreen(tester, sampleLoan());

    // The raw UUID must never be rendered, and the row must not overflow.
    expect(tester.takeException(), isNull);
    expect(find.text('c6ffa8c2-37e4-4c0c-9f4c-25c8505a4a1c'), findsNothing);
    expect(find.text('C6FFA8C2'), findsOneWidget);
  });
}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLoanApiService extends Mock implements LoanApiService {}

/// The screen only reads `state.loans`; seed it directly instead of exercising
/// the network-backed notifier. StateNotifier takes its initial state through
/// the super constructor, so the seed is assigned to `state` — not via a
/// `build()` override, which StateNotifier never calls.
class _StubLoanNotifier extends LoanNotifier {
  _StubLoanNotifier(LoansState seed)
      : super(_MockAuthRepository(), _MockLoanApiService()) {
    state = seed;
  }
}
