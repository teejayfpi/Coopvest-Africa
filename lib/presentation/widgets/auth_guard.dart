import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/auth_models.dart';
import '../../data/models/kyc_models.dart';
import '../providers/auth_provider.dart';
import '../providers/kyc_provider.dart';
import '../screens/membership/account_activation_screen.dart';

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
    final activation = _activationGate(user);
    if (activation == _GateDecision.checking) {
      // No decision yet — wait for the server's answer rather than guessing.
      return const _GateLoadingScreen();
    }
    if (activation == _GateDecision.feePending) {
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
  /// registration-fee decision, falling back to the profile only if the server
  /// stays unreachable.
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
  _GateDecision _activationGate(User? user) {
    final serverDecision = ref.read(authProvider.notifier).isFeeSettledOnServer;

    if (serverDecision == null) {
      // No server answer yet: ask, and wait. Two cold-start attempts are
      // absorbed; after that, if the backend is still unreachable, fall back to
      // the profile flag so a paying member on a bad network is not stranded.
      if (_gateAttempts < _maxGateAttempts) {
        _requestGateCheck();
        return _GateDecision.checking;
      }
      return (user?.hasSettledRegistrationFee ?? false)
          ? _GateDecision.active
          : _GateDecision.feePending;
    }

    return serverDecision ? _GateDecision.active : _GateDecision.feePending;
  }

}

/// Result of the registration-fee gate.
enum _GateDecision {
  /// Waiting on the server's activation answer.
  checking,
  /// Registration fee not settled and no exemption → Account Activation screen.
  feePending,
  /// Fee settled (or salary-deduction exempt) → dashboard.
  active,
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
