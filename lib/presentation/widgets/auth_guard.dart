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

  const AuthGuard({super.key, required this.child});

  @override
  ConsumerState<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends ConsumerState<AuthGuard> {
  bool _kycInitialized = false;
  bool _silentRetryScheduled = false;
  int _silentRetryCount = 0;
  static const int _maxSilentRetries = 3;

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

    // If not authenticated, show the child (WelcomeScreen)
    if (!authState.isAuthenticated) {
      return widget.child;
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
    if (activation == _ActivationStage.feePending) {
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

  /// Determines the membership-activation stage from the profile alone.
  ///
  /// The activation screen only renders when the *backend* confirms KYC is
  /// approved (kyc_verified) but the registration fee is not yet settled. A
  /// member whose KYC is merely submitted-but-awaiting-approval, or a profile
  /// that is 'unknown' (backend unreachable) is NOT routed here — we must never
  /// block an existing member behind a stale/ambiguous flag.
  _ActivationStage _activationGate(User? user) {
    if (user == null) return _ActivationStage.active;
    // Callers reach this gate only once the member has SUBMITTED KYC. The
    // registration fee gates dashboard access — members pay it right after
    // KYC, and the admin then verifies KYC + payment together. Gating on
    // admin approval here would let unpaid members onto the dashboard while
    // their KYC awaits review.
    //
    // Salary-deduction members are exempt: their fee is recovered from salary by
    // their employer and remitted with their contributions, so sending them to
    // the in-app payment screen would demand money through a channel that isn't
    // theirs. `hasSettledRegistrationFee` covers paid *and* exempt; the backend
    // derives the exemption in its activation gate, so this routes on exactly
    // the decision the server enforces rather than a second, client-side rule.
    if (!user.hasSettledRegistrationFee) {
      return _ActivationStage.feePending;
    }
    return _ActivationStage.active;
  }

}

/// Membership-activation stages used by AuthGuard to decide between the
/// dashboard, the KYC flow, and the Account Activation (registration fee) screen.
enum _ActivationStage {
  /// KYC submitted but the registration fee isn't settled → Account
  /// Activation screen.
  feePending,
  /// Fee settled (KYC approval is verified together with the fee by the
  /// admin) → dashboard.
  active,
}
