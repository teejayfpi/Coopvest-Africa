import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:coopvest_mobile/data/api/loan_api_service.dart';
import 'package:coopvest_mobile/data/models/announcement_models.dart';
import 'package:coopvest_mobile/data/repositories/auth_repository.dart';
import 'package:coopvest_mobile/presentation/providers/announcement_provider.dart';
import 'package:coopvest_mobile/presentation/providers/auth_provider.dart';
import 'package:coopvest_mobile/presentation/providers/contributions/contribution_provider.dart';
import 'package:coopvest_mobile/presentation/providers/contributions/contribution_settings_provider.dart';
import 'package:coopvest_mobile/presentation/providers/loan_provider.dart';
import 'package:coopvest_mobile/presentation/providers/notifications_provider.dart';
import 'package:coopvest_mobile/presentation/providers/wallet_provider.dart';
import 'package:coopvest_mobile/presentation/screens/home/home_dashboard_screen.dart';
import 'package:coopvest_mobile/presentation/widgets/common/announcement_marquee.dart';

/// Regression coverage for the reported home-screen overlap: the Wallet /
/// Savings / Loans row sat under a `Transform.translate(offset: Offset(0, -30))`
/// meant to tuck it into the green header. When the news marquee was inserted
/// between the header and the row, that -30 started pulling the cards up over
/// the 40px ticker instead, hiding all but the "NEWS" sliver.
///
/// `Transform.translate` moves paint, not layout, so the overlap was invisible
/// to layout assertions on the cards alone. These tests assert the geometric
/// relationship between the two widgets directly: the cards must start at or
/// below the marquee's bottom edge.
void main() {
  // Wider than any phone: the test font (Ahem) gives every glyph a square
  // advance, so text is far wider than in production and would overflow rows
  // that are fine on a real device. Layout geometry is what matters here, so
  // the surface is sized to keep the harness's font out of the way.
  const surface = Size(1200, 900);

  /// Seeds the data the dashboard reads, with one marquee announcement
  /// configured so the ticker actually renders.
  ///
  /// `currentUserProvider` is left null on purpose: the dashboard's reminder and
  /// realtime-notification work is gated on a signed-in member, and both reach
  /// for native plugins that do not exist in a widget test. With no user those
  /// paths return early, so the pump stays hermetic without stubbing services.
  List<Override> overrides({required bool withMarquee}) {
    final announcements = withMarquee
        ? [
            Announcement(
              id: 'n1',
              title: 'Opening date announced',
              content: 'Branch opening on the 1st.',
              type: 'general',
              createdAt: DateTime(2026, 2, 1),
              displayMode: 'marquee',
            ),
          ]
        : <Announcement>[];

    return [
      currentUserProvider.overrideWithValue(null),
      walletProvider.overrideWith((ref) => _StubWalletNotifier()),
      loanProvider.overrideWith((ref) => _StubLoanNotifier()),
      contributionProvider.overrideWith((ref) => _StubContributionNotifier()),
      notificationsProvider
          .overrideWith((ref) => _StubNotificationsNotifier()),
      announcementProvider.overrideWith(
        (ref) => _StubAnnouncementNotifier(
          AnnouncementState(announcements: announcements),
        ),
      ),
      // The obligations FutureProvider hits the network; the card handles an
      // error state, so a failing override keeps the pump hermetic.
      obligationsProvider.overrideWith((ref) async => <String, dynamic>{}),
      contributionSettingsProvider
          .overrideWith((ref) async => const ContributionSettings()),
    ];
  }

  Future<void> pumpHome(WidgetTester tester, {required bool withMarquee}) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(withMarquee: withMarquee),
        child: const MaterialApp(home: HomeDashboardScreen()),
      ),
    );
    // Settle the post-frame loads; the ticker repeats forever, so `pumpAndSettle`
    // would time out — pump a fixed number of frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the stat cards do not overlap the news marquee', (tester) async {
    await pumpHome(tester, withMarquee: true);

    expect(find.text('NEWS'), findsOneWidget,
        reason: 'the marquee should render for a marquee announcement');

    final marqueeRect = tester.getRect(find.byType(AnnouncementMarquee));
    final walletCardRect = tester.getRect(find.text('Wallet'));

    expect(
      walletCardRect.top,
      greaterThanOrEqualTo(marqueeRect.bottom),
      reason: 'the Wallet card must start at or below the ticker, not over it '
          '(top=${walletCardRect.top}, marquee bottom=${marqueeRect.bottom})',
    );
  });

  testWidgets('the marquee sits in the header, above the balance panel',
      (tester) async {
    await pumpHome(tester, withMarquee: true);

    final marqueeRect = tester.getRect(find.byType(AnnouncementMarquee));
    final balanceRect = tester.getRect(find.text('Total Balance'));

    // The whole point of moving it into the header: it must be above the
    // balance panel, so it is on screen at launch instead of below the fold.
    expect(marqueeRect.bottom, lessThan(balanceRect.top),
        reason: 'the ticker must sit above the balance panel inside the header');
  });

  testWidgets('all three stat cards are aligned on the same top edge',
      (tester) async {
    await pumpHome(tester, withMarquee: true);

    final tops = ['Wallet', 'Savings', 'Loans']
        .map((label) => tester.getRect(find.text(label)).top)
        .toList();

    expect(tops[1], closeTo(tops[0], 0.5));
    expect(tops[2], closeTo(tops[0], 0.5));
  });

  testWidgets('no news configured leaves no empty gap where the ticker was',
      (tester) async {
    await pumpHome(tester, withMarquee: false);

    // The widget is still mounted (the header always builds it) but it must
    // collapse to nothing: no strip, no NEWS marker, no reserved height.
    expect(find.text('NEWS'), findsNothing);
    expect(tester.getSize(find.byType(AnnouncementMarquee)), Size.zero);
    // The dashboard still renders its cards.
    expect(find.text('Wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockLoanAuthRepository extends Mock implements AuthRepository {}

class _MockLoanApiService extends Mock implements LoanApiService {}

class _MockContributionRepository extends Mock implements ContributionRepository {}

class _MockNotificationRepository extends Mock implements NotificationRepository {}

/// The dashboard calls every notifier's load method from `initState`. The real
/// implementations set `state` synchronously before their first `await`, and
/// Riverpod forbids mutating a provider while the tree is building, so the
/// stubs make every load a no-op: this test only cares about layout.
class _StubWalletNotifier extends WalletNotifier {
  _StubWalletNotifier() : super(_MockWalletRepository());

  @override
  Future<void> loadWallet() async {}

  @override
  Future<void> loadTransactions({
    int page = 1,
    int pageSize = 20,
    String? type,
    String? status,
  }) async {}
}

class _StubLoanNotifier extends LoanNotifier {
  _StubLoanNotifier()
      : super(_MockLoanAuthRepository(), _MockLoanApiService());

  @override
  Future<void> getLoans() async {}
}

class _StubContributionNotifier extends ContributionNotifier {
  _StubContributionNotifier() : super(_MockContributionRepository());

  @override
  Future<void> loadContributions() async {}
}

class _StubNotificationsNotifier extends NotificationsNotifier {
  _StubNotificationsNotifier() : super(_MockNotificationRepository());

  @override
  Future<void> loadNotifications({int page = 1, int pageSize = 20}) async {}
}

class _StubAnnouncementNotifier extends AnnouncementProvider {
  _StubAnnouncementNotifier(AnnouncementState seed) {
    state = seed;
  }

  @override
  Future<void> loadAnnouncements({bool refresh = false}) async {}
}
