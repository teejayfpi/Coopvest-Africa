import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:coopvest_mobile/data/api/loan_api_service.dart';
import 'package:coopvest_mobile/data/models/wallet_models.dart';
import 'package:coopvest_mobile/data/repositories/auth_repository.dart';
import 'package:coopvest_mobile/presentation/providers/loan_provider.dart';
import 'package:coopvest_mobile/presentation/providers/wallet_provider.dart';
import 'package:coopvest_mobile/presentation/screens/wallet/wallet_dashboard_screen.dart';

/// Regression coverage for the reported wallet-screen defects:
///
///   * the "Total Balance" headline showed lifetime savings (₦100,160,000)
///     while the Available/Pending figures underneath added up to ₦133,000,
///     so the headline looked like a different, unreconcilable number;
///   * the three summary rows mixed formats — Total Savings / Outstanding Loan /
///     Total Loan Applied rendered as a bare "₦100160000"/"₦0" with no
///     separators or decimals;
///   * the "Hide" pill overflowed the card and clipped to "Hid" when the
///     balance was wide.
///
/// These assert the reconciliation and the formatting, not pixel colours, so
/// they stay stable across theme tweaks.
void main() {
  // Wide surface: the test (Ahem) font makes every glyph a square, so the
  // wallet card's rows are far wider than on a real device. Layout that is fine
  // in production would overflow the harness, which is not what is under test.
  const surface = Size(1200, 1400);

  Wallet wallet({
    double available = 133000,
    double pending = 0,
    double totalSavings = 100160000,
  }) {
    return Wallet(
      id: 'w1',
      userId: 'u1',
      balance: available,
      totalContributions: totalSavings,
      totalSavings: totalSavings,
      monthlySavings: 5000,
      pendingContributions: pending,
      availableForWithdrawal: available,
      updatedAt: DateTime(2026, 2, 1),
    );
  }

  Future<void> pumpWallet(
    WidgetTester tester, {
    required WalletState seed,
    Size size = surface,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith((ref) => _StubWalletNotifier(seed)),
          loanProvider.overrideWith((ref) => _StubLoanNotifier()),
        ],
        child: const MaterialApp(
          home: WalletDashboardScreen(userId: 'u1', userName: 'Test Member'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Total Balance reconciles with Available + Pending, not savings',
      (tester) async {
    await pumpWallet(
      tester,
      seed: WalletState(
        status: WalletStatus.loaded,
        wallet: wallet(available: 133000, pending: 0, totalSavings: 100160000),
      ),
    );

    expect(find.text('Total Balance'), findsOneWidget);
    // 133,000 + 0 = 133,000 — NOT the 100,160,000 savings figure.
    final headline = tester.widget<Text>(
      find.byKey(const Key('wallet-total-balance')),
    );
    expect(headline.data, '₦133,000.00',
        reason: 'the headline must show available + pending');
    // Total Savings (100,160,000) is still shown, but as its own row — it must
    // not be the headline.
    expect(headline.data, isNot('₦100,160,000.00'));
  });

  testWidgets('Total Balance includes pending contributions', (tester) async {
    await pumpWallet(
      tester,
      seed: WalletState(
        status: WalletStatus.loaded,
        wallet: wallet(available: 133000, pending: 2000, totalSavings: 0),
      ),
    );

    final headline = tester.widget<Text>(
      find.byKey(const Key('wallet-total-balance')),
    );
    expect(headline.data, '₦135,000.00');
  });

  testWidgets('summary rows use grouped, two-decimal currency', (tester) async {
    await pumpWallet(
      tester,
      seed: WalletState(
        status: WalletStatus.loaded,
        wallet: wallet(available: 133000, pending: 0, totalSavings: 100160000),
      ),
    );

    // Total Savings is grouped and decimal-formatted.
    expect(find.text('₦100,160,000.00'), findsOneWidget);
    // Zero values read ₦0.00, not a bare ₦0.
    expect(find.text('₦0'), findsNothing);
    expect(find.text('₦0.00'), findsWidgets);
  });

  testWidgets('Hide pill stays inside the card on a wide balance',
      (tester) async {
    await pumpWallet(
      tester,
      seed: WalletState(
        status: WalletStatus.loaded,
        wallet: wallet(available: 100160000, pending: 0, totalSavings: 100160000),
      ),
    );

    final pill = find.text('Hide');
    expect(pill, findsOneWidget,
        reason: 'the pill must render "Hide", not the clipped "Hid"');
    expect(find.text('Hid'), findsNothing);

    // The pill sits in the header Row of the balance card; assert it does not
    // extend past the card's right edge.
    final card = tester.getRect(find.byKey(const Key('wallet-balance-card')));
    final pillRect = tester.getRect(pill);
    expect(
      pillRect.right,
      lessThanOrEqualTo(card.right + 0.5),
      reason: 'Hide pill must not overflow the card '
          '(pill right=${pillRect.right}, card right=${card.right})',
    );
  });
}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockLoanAuthRepository extends Mock implements AuthRepository {}

class _MockLoanApiService extends Mock implements LoanApiService {}

/// The screen calls every notifier's load method from `initState`. Riverpod
/// forbids mutating a provider while the tree is building, so the stubs make
/// every load a no-op and rely on the seeded state instead.
class _StubWalletNotifier extends WalletNotifier {
  _StubWalletNotifier(WalletState seed) : super(_MockWalletRepository()) {
    state = seed;
  }

  @override
  Future<void> loadWallet() async {}

  @override
  Future<void> loadTransactions({
    int page = 1,
    int pageSize = 20,
    String? type,
    String? status,
  }) async {}

  @override
  Future<void> loadSavingsGoals({int page = 1, int pageSize = 20}) async {}
}

class _StubLoanNotifier extends LoanNotifier {
  _StubLoanNotifier() : super(_MockLoanAuthRepository(), _MockLoanApiService());

  @override
  Future<void> getLoans() async {}
}
