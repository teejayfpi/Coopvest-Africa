import 'package:flutter/material.dart';

import '../../config/theme_config.dart';
import 'common/buttons.dart';

/// Shown when the app is signed in but cannot reach the server to confirm the
/// member's registration-fee status, and the app has no way to tell whether the
/// fee is settled.
///
/// This exists because the alternative was worse. The activation gate used to
/// fall back to the cached profile when the server was unreachable, and the
/// cached profile's fee flags default to `false`. So a member who had already
/// paid — opening the app on a train, in a basement, on a flaky connection —
/// was shown the ₦5,000 payment screen for a fee they had settled. The app was
/// reporting "unpaid" when what it actually meant was "unknown".
///
/// "Unknown" is a real third state and gets its own screen. It never claims the
/// member owes money, and it never lets them past the gate either: the server
/// is still the only thing that can settle the question, so this screen offers
/// a retry rather than a verdict.
///
/// It also offers sign-out. Without it a member whose server is genuinely
/// unreachable (or whose session is broken) would be stuck here with no way
/// forward, which is the trap the old payment screen set.
class OfflineGateScreen extends StatefulWidget {
  /// Re-runs the activation-gate check. Should return true when a server answer
  /// was obtained, false when the server is still unreachable.
  final Future<bool> Function() onRetry;

  /// Signs the member out and returns them to the welcome screen. This is the
  /// escape hatch for a session the server will never accept.
  final Future<void> Function() onSignOut;

  const OfflineGateScreen({
    super.key,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  State<OfflineGateScreen> createState() => _OfflineGateScreenState();
}

class _OfflineGateScreenState extends State<OfflineGateScreen> {
  bool _retrying = false;

  /// Set after a retry that still could not reach the server, so the screen can
  /// acknowledge the second failure instead of silently doing nothing. Silence
  /// after a tap reads as a broken button.
  bool _stillUnreachable = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _stillUnreachable = false;
    });

    final reached = await widget.onRetry();

    if (!mounted) return;
    setState(() {
      _retrying = false;
      _stillUnreachable = !reached;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: CoopvestColors.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CoopvestColors.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 48,
                          color: CoopvestColors.warning,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Can't reach Coopvest right now",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: CoopvestColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "We couldn't confirm your membership status because the "
                    'connection dropped. This is a problem with the network, '
                    'not with your account — nothing has changed and you have '
                    'not been charged.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: CoopvestColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reconnect to Wi-Fi or mobile data, then try again.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: CoopvestColors.textHint,
                    ),
                  ),
                  if (_stillUnreachable) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CoopvestColors.errorSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 20,
                            color: CoopvestColors.errorText,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Still no connection. Check that you are online '
                              'and try again.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: CoopvestColors.errorText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: _retrying ? 'Checking…' : 'Try again',
                    isLoading: _retrying,
                    onPressed: _retry,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'Sign out',
                    isEnabled: !_retrying,
                    onPressed: () => widget.onSignOut(),
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
