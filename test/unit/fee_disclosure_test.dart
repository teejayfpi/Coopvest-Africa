import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/config/app_config.dart';
import 'package:coopvest_mobile/core/services/fee_disclosure_store.dart';
import 'package:coopvest_mobile/data/models/fee_schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the first-run fee disclosure.
///
/// The disclosure is only worth having if two things hold:
///
///   1. It is shown when it has not been shown — otherwise a member can reach
///      the sign-up button without ever seeing the charges.
///   2. It is shown *again* when the charges change — otherwise "shown once"
///      becomes "never updated", and a member is held to a price list they
///      were never shown.
///
/// These tests pin both, plus the rule that a bundled (offline) schedule never
/// counts as the published one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FeeDisclosureStore decides when to show', () {
    test('an unseen hash needs showing', () async {
      expect(await FeeDisclosureStore.needsShowing('abc123'), isTrue);
    });

    test('a hash that was shown does not need showing again', () async {
      await FeeDisclosureStore.markShown('abc123');
      expect(await FeeDisclosureStore.needsShowing('abc123'), isFalse);
    });

    test('a changed hash needs showing again', () async {
      await FeeDisclosureStore.markShown('abc123');
      // The charges changed on the server; the member has not seen the new ones.
      expect(await FeeDisclosureStore.needsShowing('def456'), isTrue);
    });

    test('a bundled schedule (empty hash) always needs showing', () async {
      // An empty hash is the offline fallback, which is never the published
      // revision. It must not suppress the real schedule once the member is
      // online.
      expect(await FeeDisclosureStore.needsShowing(''), isTrue);
    });

    test('a bundled schedule is not recorded as shown', () async {
      await FeeDisclosureStore.markShown('');
      expect(await FeeDisclosureStore.shownHash(), isNull);
      // So the live schedule still supersedes it.
      expect(await FeeDisclosureStore.needsShowing('abc123'), isTrue);
    });

    test('the shown hash survives a relaunch', () async {
      await FeeDisclosureStore.markShown('abc123');
      expect(await FeeDisclosureStore.shownHash(), 'abc123');
    });

    test('shownAt records when it was shown', () async {
      final when = DateTime.utc(2026, 11, 8, 9, 30);
      await FeeDisclosureStore.markShown('abc123', at: when);
      expect(await FeeDisclosureStore.shownAt(), when);
    });
  });

  group('FeeSchedule.bundled agrees with the constants the app charges from', () {
    FeeCharge charge(String id) =>
        FeeSchedule.bundled().charges.firstWhere((c) => c.id == id);

    test('the registration fee matches AppConfig', () {
      expect(charge('registration_fee').amount, AppConfig.entranceFee);
    });

    test('the monthly contribution matches AppConfig', () {
      expect(charge('monthly_contribution').amount, AppConfig.minContribution);
    });

    test('the administrative fee total matches AppConfig', () {
      expect(charge('administrative_fee').amount, AppConfig.totalMonthlyLevies);
    });

    test('the administrative fee is itemised into both levies', () {
      final components = charge('administrative_fee').components;
      expect(components.map((c) => c.name), [
        'Administrative charges',
        'Development levy',
      ]);
      expect(
        components.map((c) => c.amount),
        [AppConfig.administrativeCharges, AppConfig.developmentLevy],
      );
      // The parts must add up to the total shown beside them.
      final sum = components.fold<num>(0, (a, c) => a + c.amount);
      expect(sum, AppConfig.totalMonthlyLevies);
    });

    test('the late repayment fine matches AppConfig', () {
      expect(charge('late_repayment_fine').amount, AppConfig.lateRepaymentFine);
    });

    test('the registration fee note does not say it is added to the '
        'monthly contribution', () {
      final note = charge('registration_fee').note!.toLowerCase();
      // The affirmative claim must be absent; the negated one must be present.
      expect(note, isNot(contains('is added to your monthly contribution')));
      expect(note, contains('not added to your monthly contribution'));
    });

    test('the administrative fee names Administrative charges, not AGM levy',
        () {
      final names = charge('administrative_fee').components.map((c) => c.name);
      expect(names, contains('Administrative charges'));
      expect(names.any((n) => n.toLowerCase().contains('agm')), isFalse);
    });

    test('the monthly contribution is flagged as not a charge', () {
      expect(charge('monthly_contribution').isCharge, isFalse);
      expect(charge('registration_fee').isCharge, isTrue);
    });

    test('the bundled schedule carries no hash', () {
      // A bundled schedule must never be mistaken for a server-confirmed one.
      expect(FeeSchedule.bundled().hash, isEmpty);
    });

    test('every loan product the app offers has a published rate', () {
      final products =
          FeeSchedule.bundled().loanInterestRates.map((r) => r.name).toSet();
      expect(products, {
        'Quick Loan',
        'Flexi Loan',
        'Stable Loan (12 months)',
        'Stable Loan (18 months)',
        'Premium Loan',
        'Maxi Loan',
      });
    });

    test('it states plainly which charges do not apply', () {
      expect(FeeSchedule.bundled().notCharged, isNotEmpty);
    });
  });

  group('FeeSchedule.fromJson parses the backend payload', () {
    test('reads the hash, charges, components, rates and exclusions', () {
      final schedule = FeeSchedule.fromJson({
        'success': true,
        'schedule_hash': 'deadbeefdeadbeef',
        'version': '2026-11-08',
        'currency': 'NGN',
        'charges': [
          {
            'id': 'registration_fee',
            'label': 'Registration fee',
            'amount': 5000,
            'frequency': 'one-time',
            'refundable': false,
            'note': 'A charge payable to the cooperative.',
          },
          {
            'id': 'administrative_fee',
            'label': 'Monthly administrative fee',
            'amount': 1500,
            'frequency': 'monthly',
            'components': [
              {'name': 'Administrative charges', 'amount': 1000},
              {'name': 'Development levy', 'amount': 500},
            ],
          },
        ],
        'loan_interest_rates': [
          {'product': 'Quick Loan', 'rate': 7.5},
        ],
        'not_charged': ['Withdrawal fee'],
      });

      expect(schedule.hash, 'deadbeefdeadbeef');
      expect(schedule.version, '2026-11-08');
      expect(schedule.charges.length, 2);
      expect(schedule.charges.first.amount, 5000);
      expect(schedule.charges.first.refundable, isFalse);
      expect(schedule.charges[1].components.length, 2);
      expect(schedule.loanInterestRates.first.name, 'Quick Loan');
      expect(schedule.loanInterestRates.first.amount, 7.5);
      expect(schedule.notCharged, ['Withdrawal fee']);
    });

    test('drops malformed charges rather than showing a blank row', () {
      final schedule = FeeSchedule.fromJson({
        'charges': [
          {'id': '', 'label': '', 'amount': 1},
          {'id': 'registration_fee', 'label': 'Registration fee', 'amount': 5000},
        ],
      });
      expect(schedule.charges.length, 1);
      expect(schedule.charges.single.id, 'registration_fee');
    });

    test('survives a payload with no charges or rates', () {
      final schedule = FeeSchedule.fromJson({'schedule_hash': 'x'});
      expect(schedule.charges, isEmpty);
      expect(schedule.loanInterestRates, isEmpty);
      expect(schedule.notCharged, isEmpty);
    });
  });
}
