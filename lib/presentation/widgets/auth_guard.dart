import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/registration_fee_status_store.dart';
import '../../data/models/auth_models.dart';
import '../../data/models/kyc_models.dart';
import '../providers/auth_provider.dart';
import '../providers/kyc_provider.dart';
import '../screens/membership/account_activation_screen.dart';
import 'offline_gate_screen.dart';

/// AuthGuard determines where to send the user based on their auth state:
/// - Not authenticated → child (Welcome/Login)
/// - Authenticated but registration not complete → Continue registration
/// - Authenticated but KYC not yet submitted → Continue KYC
/// - Authenticated and KYC already submitted (pending review/approved) → Dashboard
///
/// Previously this forced the KYC flow whenever `user.kycStatus != 'approved'`,
/// which re-prompted KYC on every app start for members who had already
/// submitted but were still awaiting admin approval. We now gate on whether the
/// member has *submitted* KYC (loaded from the backend), not on approval.
class AuthGuard extends ConsumerStatefulWidget {
  final Widget child;

  /// Rendered instead of [child] when the member is NOT authenticated.
  ///
  /// Defaults to [child], which is correct for the root guard whose child
  /// handles the signed-out state itself (WelcomeScreen). It must be set when
  /// the guard wraps a screen that must never be shown while signed out — e.g.
  /// the `/home` route, whose child is the dashboard: returning that child on
  /// sign-out would flash the dashboard at a member who just logged out.
  final Widget? signedOutChild;

  const AuthGuard({super.key, required this.child, this.signedOutChild});

  @override
  ConsumerState<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends ConsumerState<AuthGuard> {
  bool _kycInitialized = false;
  bool _silentRetryScheduled = false;
  int _silentRetryCount = 0;
  static const int _maxSilentRetries = 3;

  /// Server gate checks started while no decision was available yet.
  int _gateAttempts = 0;

  /// True while a gate request is in flight, so concurrent builds do not each
  /// fire one and burn through [_maxGateAttempts] before the first reply lands.
  bool _gateCheckInFlight = false;

  /// How many times the guard will wait on the server before falling back to
  /// the profile flag from the last `/auth/me`. Two absorbs a normal Render
  /// cold start without stranding a member on a spinner when the backend is
  /// genuinely unreachable.
  static const int _maxGateAttempts = 2;

  /// The device's durable "the server once confirmed this fee is settled"
  /// flag, loaded once per guard lifetime. Null until the read completes.
  ///
  /// This is the only thing that can resolve the gate without the server, and
  /// it can only ever resolve it to *active* — see [_activationGate].
  bool? _settledConfirmedOnDevice;

  /// Which member [_settledConfirmedOnDevice] belongs to, so a change of
  /// account does not reuse the previous member's confirmation.
  String? _settledConfirmedForUserId;

  /// Ask the server for its activation-gate decision, at most [_maxGateAttempts]
  /// times, and rebuild once it lands.
  ///
  /// The guard re-runs this on every (re)build, and the guard is rebuilt by the
  /// paths a member can use to escape the payment screen — pressing back,
  /// relaunching the app, or signing in again — plus every return from
  /// background. That is what makes the gate non-skippable: it never trusts the
  /// route it was handed or a stale profile; it re-asks.
  void _requestGateCheck() {
    if (_gateCheckInFlight) return;
    if (_gateAttempts >= _maxGateAttempts) return;
    _gateAttempts++;
    _gateCheckInFlight = true;
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(authProvider.notifier).refreshGateStatus();
      _gateCheckInFlight = false;
      if (mounted) setState(() {});
    });
  }

  /// Re-ask the server for the offline screen's "Try again".
  ///
  /// Returns whether a server answer was obtained, so the screen can say so
  /// instead of appearing to do nothing. The attempt budget is deliberately not
  /// reset here: on success the server decision resolves the gate outright, and
  /// on failure the budget is already spent, which is what keeps the guard on
  /// the offline screen rather than looping back to the spinner.
  Future<bool> _retryGateCheck() async {
    if (_gateCheckInFlight) return false;
    _gateCheckInFlight = true;
    final reached = await ref.read(authProvider.notifier).refreshGateStatus();
    _gateCheckInFlight = false;
    if (mounted) setState(() {});
    return reached;
  }

  /// Load the device's settled-fee confirmation for [userId], once per member.
  void _ensureSettledConfirmedLoaded(String? userId) {
    if (userId == null || userId.isEmpty) return;
    if (_settledConfirmedForUserId == userId) return;
    _settledConfirmedForUserId = userId;
    _settledConfirmedOnDevice = null;
    Future.microtask(() async {
      final confirmed = await RegistrationFeeStatusStore.isSettledConfirmed(userId);
      if (!mounted) return;
      // Guard against a late read landing after a different member signed in.
      if (_settledConfirmedForUserId != userId) return;
      if (_settledConfirmedOnDevice == confirmed) return;
      setState(() => _settledConfirmedOnDevice = confirmed);
    });
  }

  /// Retry the KYC fetch quietly after a delay (gives a cold-starting backend
  /// time to wake). Silent retries never toggle the provider's loading status,
  /// so the dashboard stays on screen instead of flashing a spinner.
  void _scheduleSilentKycRetry() {
    if (_silentRetryScheduled || _silentRetryCount >= _maxSilentRetries) return;
    _silentRetryScheduled = true;
    Future.delayed(const Duration(seconds: 8), () async {
      _silentRetryScheduled = false;
      if (!mounted) return;
      _silentRetryCount++;
      await ref.read(kycProvider.notifier).initializeKYC(silent: true);
    });
  }


  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // If not authenticated, show the signed-out child (defaults to widget.child,
    // which is WelcomeScreen at the root).
    if (!authState.isAuthenticated) {
      _gateAttempts = 0;
      return widget.signedOutChild ?? widget.child;
    }

    // NOTE: there is deliberately no `registrationCompleted` gate here.
    //
    // It used to be:
    //   if (user != null && !user.registrationCompleted) {
    //     return const RegistrationOnboardingScreen(registrationData: {});
    //   }
    // which forced every member through the 8-step profile form before they
    // could reach the payment screen — the length members complained about.
    // `registration_completed` is still set by the backend once the fee
    // settles (and by the KYC flow), and is still shown as a progress signal,
    // but it no longer blocks entry to the app. The questions it collected are
    // asked during KYC, which is deferred to the point of applying for a loan.
    //
    // The block below must stay reachable for an authenticated member whose
    // profile has not been filled in: they pay the fee and get their
    // dashboard, with an incomplete profile simply meaning no loan yet.

    // The dashboard gate is the registration FEE, not KYC.
    //
    // Onboarding used to run: sign up -> verify -> contribution type -> 8-step
    // profile -> KYC form -> then finally pay the fee, and the dashboard
    // required KYC *approval*, so a member who had paid still could not see
    // their money while an admin reviewed their documents. The flow is now:
    // sign up -> verify -> contribution type -> pay -> dashboard, with KYC
    // deferred to the point of borrowing (see AuthGuard's `kycRequiredForCredit`
    // note and the requireActivated mounts in the backend).
    //
    // So route on the fee alone. The server is authoritative and mirrors this
    // split (requireRegistrationPaid on wallet/savings, requireActivated on
    // loans), so the client gate matches what the API will actually allow.
    _ensureSettledConfirmedLoaded(user?.id);
    final activation = _activationGate(user);
    if (activation == GateDecision.checking) {
      // No decision yet — wait for the server's answer rather than guessing.
      return const _GateLoadingScreen();
    }
    if (activation == GateDecision.unreachable) {
      // Signed in, but we could not reach the server and have no confirmation
      // that the fee is settled. This is deliberately NOT the payment screen:
      // "unknown" is not "owes money". See OfflineGateScreen.
      return OfflineGateScreen(
        onRetry: _retryGateCheck,
        onSignOut: () => ref.read(authProvider.notifier).logout(),
      );
    }
    if (activation == GateDecision.feePending) {
      return const AccountActivationScreen();
    }

    // Fee settled -> dashboard. Fetch KYC status in the background so the
    // loan flow and the profile screen have it ready, but never block on it:
    // a member with a settled fee is allowed onto the dashboard regardless of
    // where their KYC review has got to.
    final kycState = ref.watch(kycProvider);
    if (!_kycInitialized) {
      _kycInitialized = true;
      Future.microtask(() {
        if (mounted) ref.read(kycProvider.notifier).initializeKYC(silent: true);
      });
    }
    if (kycState.status != KYCStatus.loaded) {
      _scheduleSilentKycRetry();
    }

    return widget.child;
  }

  /// Determines the membership-activation stage from the server's
  /// registration-fee decision, falling back only to a *durable* settled
  /// confirmation when the server is unreachable.
  ///
  /// The activation screen only renders when the registration fee is not
  /// settled. Salary-deduction members are exempt: their fee is recovered from
  /// salary by their employer and remitted with their contributions, so sending
  /// them to the in-app payment screen would demand money through a channel
  /// that isn't theirs.
  ///
  /// The decision comes from the server (`GET /app/home-status`), not the
  /// profile, because the profile can be stale in exactly the situation this
  /// gate defends against: a Direct Deposit member who pressed back out of the
  /// payment screen, or signed out and in again, can hold a cached profile
  /// whose `registration_fee_paid` no longer matches the server. The server
  /// derives the salary-deduction exemption itself, so the app never applies a
  /// second, client-side rule.
  ///
  /// ## Why the fallback is asymmetric
  ///
  /// When the server is unreachable the gate must not read the cached profile's
  /// fee flags, because those flags default to `false` on a cold start: doing so
  /// told a member who had paid that they still owed the fee, and sent them to
  /// the payment screen on any bad connection. The two outcomes are not
  /// symmetric, so the fallbacks are not either:
  ///
  ///   - **Settled can be believed offline.** A fee, once settled, stays
  ///     settled. [_settledConfirmedOnDevice] records a *past server
  ///     confirmation* of that, so it can safely route the member to the
  ///     dashboard without the network.
  ///   - **Unsettled cannot.** "Not settled" is the claim the server re-check
  ///     exists to make, so no local state may assert it. If we cannot reach the
  ///     server and have no settled confirmation, the answer is "unknown" —
  ///     [GateDecision.unreachable] — which is neither the dashboard nor an
  ///     accusation of non-payment.
  ///
  /// The dashboard this unlocks is not a bypass: the backend still enforces
  /// `requireRegistrationPaid`, so an unpaid member who somehow got past the
  /// client gate would be refused by every gated endpoint anyway.
  GateDecision _activationGate(User? user) {
    final decision = decideRegistrationFeeGate(
      serverDecision: ref.read(authProvider.notifier).isFeeSettledOnServer,
      canAskServer: _gateAttempts < _maxGateAttempts,
      settledConfirmedOnDevice: _settledConfirmedOnDevice == true,
      profileClaimsSettled: user?.hasSettledRegistrationFee ?? false,
    );
    if (decision == GateDecision.checking) _requestGateCheck();
    return decision;
  }
}

/// The registration-fee gate decision, as a pure function of everything the
/// guard knows.
///
/// Pulled out of the widget so it can be tested directly. The offline
/// false-payment bug lived entirely in this decision, and reaching it through a
/// widget test would have required standing up a fake server and a fake auth
/// session; here each rule is one call with plain booleans. Every branch is
/// pinned in `test/unit/registration_fee_gate_test.dart`.
///
/// [serverDecision] is the server's answer, or null when it has not been
/// obtained (unreachable, or not asked yet). [canAskServer] is false once the
/// attempt budget is spent. [settledConfirmedOnDevice] is a *past* server
/// confirmation of settlement, loaded from disk. [profileClaimsSettled] is the
/// cached profile's own claim.
///
/// The asymmetry that fixes the bug: an unreachable server may be resolved to
/// [GateDecision.active] (permissive) but never to [GateDecision.feePending]
/// (accusatory). When nothing permissive applies the result is
/// [GateDecision.unreachable] — "unknown", which the guard renders as a retry
/// screen rather than a payment demand.
GateDecision decideRegistrationFeeGate({
  required bool? serverDecision,
  required bool canAskServer,
  required bool settledConfirmedOnDevice,
  required bool profileClaimsSettled,
}) {
  // The server answered — it is authoritative, in both directions.
  if (serverDecision != null) {
    return serverDecision ? GateDecision.active : GateDecision.feePending;
  }

  // No answer yet and budget remains: wait on the server rather than guess.
  if (canAskServer) return GateDecision.checking;

  // Unreachable. A settled fee, once the server confirmed it, stays settled —
  // believe the device's record so a paying member on a bad connection is not
  // asked to pay again.
  if (settledConfirmedOnDevice) return GateDecision.active;

  // A cached profile claiming paid is still only ever permissive, so accept it.
  // It is never used to conclude the opposite.
  if (profileClaimsSettled) return GateDecision.active;

  // Genuinely unknown. Never guess "unpaid" — that is the bug this fixes.
  return GateDecision.unreachable;
}

/// Result of the registration-fee gate.
enum GateDecision {
  /// Waiting on the server's activation answer.
  checking,
  /// Registration fee not settled and no exemption → Account Activation screen.
  feePending,
  /// Fee settled (or salary-deduction exempt) → dashboard.
  active,
  /// Signed in, but the server could not be reached and no settled
  /// confirmation exists → offline retry screen, NOT the payment screen.
  unreachable,
}

/// Shown while the server's activation answer is in flight, so the guard never
/// briefly renders the dashboard an unpaid member is not entitled to.
class _GateLoadingScreen extends StatelessWidget {
  const _GateLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
