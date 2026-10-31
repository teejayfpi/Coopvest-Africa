import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/presentation/widgets/auth_guard.dart';

/// Regression tests for the offline false-payment bug.
///
/// Reported symptom: opening the app with no network (or an unstable one) took
/// members to the registration-fee payment screen.
///
/// Root cause: when `GET /app/home-status` failed, the gate fell back to the
/// cached profile's fee flags, which default to `false` on a cold start. The
/// app was answering "unpaid" when it actually meant "I don't know". These tests
/// pin the decision that fixes it.
///
/// The invariant, stated once: **an unreachable server may never produce
/// [GateDecision.feePending].** Only the server can conclude a fee is unpaid, so
/// every offline branch must resolve to `active` (if something permissive is
/// known) or `unreachable` (a retry screen) — never the payment screen.
void main() {
  group('offline gate never accuses a member of not paying', () {
    test(
        'the reported bug: offline, budget spent, no confirmation, cold profile '
        '→ unreachable, NOT feePending', () {
      final decision = decideRegistrationFeeGate(
        serverDecision: null, // /app/home-status failed
        canAskServer: false, // both attempts spent
        settledConfirmedOnDevice: false, // nothing cached yet
        profileClaimsSettled: false, // the cold-start profile default
      );

      expect(decision, GateDecision.unreachable);
      expect(decision, isNot(GateDecision.feePending),
          reason: 'this is exactly the screen the member was wrongly shown');
    });

    test('offline with a device-confirmed settled fee → dashboard', () {
      // The member paid in a previous session; the server confirmed it then and
      // we recorded it. Opening offline must land on the dashboard.
      final decision = decideRegistrationFeeGate(
        serverDecision: null,
        canAskServer: false,
        settledConfirmedOnDevice: true,
        profileClaimsSettled: false,
      );

      expect(decision, GateDecision.active);
    });

    test('offline with a cached profile that claims paid → dashboard', () {
      // A paid claim is permissive, so it is believed even without the server.
      final decision = decideRegistrationFeeGate(
        serverDecision: null,
        canAskServer: false,
        settledConfirmedOnDevice: false,
        profileClaimsSettled: true,
      );

      expect(decision, GateDecision.active);
    });

    test('no offline combination ever yields feePending', () {
      // Exhaustive: with no server answer, feePending must be unreachable as an
      // outcome. This is the property, not just the examples.
      for (final canAsk in [true, false]) {
        for (final onDevice in [true, false]) {
          for (final profile in [true, false]) {
            final decision = decideRegistrationFeeGate(
              serverDecision: null,
              canAskServer: canAsk,
              settledConfirmedOnDevice: onDevice,
              profileClaimsSettled: profile,
            );
            expect(decision, isNot(GateDecision.feePending),
                reason: 'canAsk=$canAsk onDevice=$onDevice profile=$profile');
          }
        }
      }
    });
  });

  group('the server still decides when it can be reached', () {
    test('server says settled → dashboard', () {
      expect(
        decideRegistrationFeeGate(
          serverDecision: true,
          canAskServer: false,
          settledConfirmedOnDevice: false,
          profileClaimsSettled: false,
        ),
        GateDecision.active,
      );
    });

    test('server says NOT settled → payment screen', () {
      // The gate still works. A genuinely unpaid member is routed to payment
      // when the server actually says so.
      expect(
        decideRegistrationFeeGate(
          serverDecision: false,
          canAskServer: false,
          settledConfirmedOnDevice: false,
          profileClaimsSettled: false,
        ),
        GateDecision.feePending,
      );
    });

    test('a server "unpaid" overrules a profile that claims paid', () {
      // The anti-bypass property from the existing gate: the server wins, so a
      // stale profile cannot talk its way onto the dashboard.
      expect(
        decideRegistrationFeeGate(
          serverDecision: false,
          canAskServer: false,
          settledConfirmedOnDevice: false,
          profileClaimsSettled: true,
        ),
        GateDecision.feePending,
      );
    });

    test('a server "unpaid" overrules a stale device confirmation', () {
      // If the device wrongly holds a settled confirmation, the server's live
      // answer still wins. Local state is only ever consulted when the server
      // is silent.
      expect(
        decideRegistrationFeeGate(
          serverDecision: false,
          canAskServer: false,
          settledConfirmedOnDevice: true,
          profileClaimsSettled: true,
        ),
        GateDecision.feePending,
      );
    });
  });

  group('waiting on the server', () {
    test('no answer yet with budget left → checking, not a verdict', () {
      final decision = decideRegistrationFeeGate(
        serverDecision: null,
        canAskServer: true,
        settledConfirmedOnDevice: true,
        profileClaimsSettled: true,
      );

      // Even with permissive local state, the guard waits for the server while
      // it still can — the local state is only a fallback for when it cannot.
      expect(decision, GateDecision.checking);
    });
  });
}
