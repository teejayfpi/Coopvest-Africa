import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:coopvest_mobile/core/utils/loan_eligibility.dart';
import 'package:coopvest_mobile/data/models/contributions/monthly_contribution.dart';
import 'package:coopvest_mobile/data/models/auth_models.dart';
import 'package:coopvest_mobile/data/repositories/auth_repository.dart';
import 'package:coopvest_mobile/data/models/wallet_models.dart';
import 'package:coopvest_mobile/data/api/loan_api_service.dart';
import 'package:coopvest_mobile/presentation/providers/auth_provider.dart';
import 'package:coopvest_mobile/presentation/providers/contributions/contribution_provider.dart';
import 'package:coopvest_mobile/presentation/providers/loan_provider.dart';
import 'package:coopvest_mobile/presentation/providers/wallet_provider.dart';
import 'package:coopvest_mobile/presentation/widgets/loan/loan_eligibility_card.dart';

/// The dashboard card is the most-seen statement of the loan rule in the app.
/// It used to compute eligibility from membership tenure alone, so a member six
/// months in with no contributions at all was shown an "Eligible" badge and a
/// working Apply button, then collected a 403 from the server. These tests pin
/// both halves of the rule.
class _MockContributionRepository extends Mock implements ContributionRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockLoanAuthRepository extends Mock implements AuthRepository {}

class _MockLoanApiService extends Mock implements LoanApiService {}

/// The card reads the wallet for its max-loan figure. The stub keeps the pump
/// off the network and off Supabase.
class _StubWalletNotifier extends WalletNotifier {
  _StubWalletNotifier() : super(_MockWalletRepository());

  @override
  Future<void> loadWallet() async {}
}

class _StubLoanNotifier extends LoanNotifier {
  _StubLoanNotifier()
      : super(_MockLoanAuthRepository(), _MockLoanApiService());

  @override
  Future<void> getLoans() async {}
}

class _StubContributionNotifier extends ContributionNotifier {
  _StubContributionNotifier(ContributionState initial)
      : super(_MockContributionRepository()) {
    state = initial;
  }

  @override
  Future<void> loadContributions() async {}
}

MonthlyContribution contribution(String month) {
  final parts = month.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 15);
  return MonthlyContribution(
    id: 'c-$month',
    userId: 'u1',
    contributionMonth: month,
    amount: 5000,
    type: ContributionType.monthly,
    status: ContributionStatus.successful,
    createdAt: date,
    updatedAt: date,
    postedDate: date,
  );
}

/// Six months ending last month, so the run is current under the grace period
/// whatever the day the test runs.
List<MonthlyContribution> currentSixMonthRun() {
  final now = DateTime.now();
  return List.generate(6, (i) {
    final d = DateTime(now.year, now.month - (5 - i), 15);
    return contribution('${d.year}-${d.month.toString().padLeft(2, '0')}');
  });
}

/// A member who joined [months] ago. Tenure is derived from `createdAt`.
User member({int months = 12}) {
  final joined = DateTime.now();
  return User(
    id: 'u1',
    email: 'member@example.com',
    name: 'Test Member',
    kycStatus: 'verified',
    createdAt: DateTime(joined.year, joined.month - months, joined.day),
  );
}

Future<void> pumpCard(
  WidgetTester tester, {
  required List<MonthlyContribution> contributions,
  ServerEligibility? server,
  User? user,
  Size size = const Size(420, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contributionProvider.overrideWith(
          (ref) => _StubContributionNotifier(
            ContributionState(
              status: ContributionLoadStatus.loaded,
              contributions: contributions,
            ),
          ),
        ),
        serverEligibilityProvider.overrideWith((ref) async => server),
        currentUserProvider.overrideWithValue(user ?? member()),
        walletProvider.overrideWith((ref) => _StubWalletNotifier()),
        loanProvider.overrideWith((ref) => _StubLoanNotifier()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: LoanEligibilityCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tenure with no contributions is not shown as eligible',
      (tester) async {
    // The reported case: membership is fine, nothing has been saved.
    await pumpCard(tester, contributions: const []);

    expect(tester.takeException(), isNull);
    expect(find.text('Eligible'), findsNothing);
    expect(find.text('You qualify for a loan!'), findsNothing);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Apply for a Loan Now'), findsNothing);
  });

  testWidgets('six consecutive saving months shows eligible', (tester) async {
    await pumpCard(tester, contributions: currentSixMonthRun());

    expect(find.text('Eligible'), findsOneWidget);
    expect(find.text('You qualify for a loan!'), findsOneWidget);
  });

  testWidgets('the server verdict wins over the local page', (tester) async {
    // The app holds one page of contributions; the server holds all of them.
    // When they disagree, the server is right.
    await pumpCard(
      tester,
      contributions: const [],
      server: const ServerEligibility(
        eligible: true,
        membershipMonths: 8,
        membershipRequired: 6,
        consecutiveMonths: 6,
        consecutiveRequired: 6,
        isCurrent: true,
        membershipMet: true,
      ),
    );

    expect(find.text('Eligible'), findsOneWidget);
  });

  testWidgets('a server refusal explains itself on the card', (tester) async {
    await pumpCard(
      tester,
      contributions: currentSixMonthRun(),
      server: const ServerEligibility(
        eligible: false,
        membershipMonths: 8,
        membershipRequired: 6,
        consecutiveMonths: 6,
        consecutiveRequired: 6,
        isCurrent: false,
        membershipMet: true,
        reason: 'Your contributions are not current.',
      ),
    );

    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Your contributions are not current.'), findsOneWidget);
  });

  testWidgets('renders without overflowing a narrow screen', (tester) async {
    await pumpCard(
      tester,
      contributions: currentSixMonthRun(),
      size: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);
  });
}
