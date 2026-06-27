import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import 'api_client.dart';

/// Session timeout configuration
class SessionConfig {
  /// How often to check if session is still valid (in seconds)
  static const int checkIntervalSeconds = 60;
  
  /// How long until session expires (in seconds) - 30 minutes default
  static const int sessionTimeoutSeconds = 30 * 60;
  
  /// How long before expiry to start showing warnings (in seconds) - 5 minutes
  static const int warningThresholdSeconds = 5 * 60;
}

/// Session state
enum SessionState {
  active,
  expiring,
  expired,
  checking,
}

/// Session timeout service
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Timer? _checkTimer;
  Timer? _expirationTimer;
  SessionState _state = SessionState.active;
  DateTime? _sessionStartTime;
  DateTime? _lastActivityTime;
  VoidCallback? _onSessionExpiring;
  VoidCallback? _onSessionExpired;
  int _remainingSeconds = SessionConfig.sessionTimeoutSeconds;

  SessionState get state => _state;
  int get remainingSeconds => _remainingSeconds;
  bool get isActive => _state == SessionState.active || _state == SessionState.expiring;

  /// Initialize session tracking
  void startSession({
    VoidCallback? onExpiring,
    VoidCallback? onExpired,
  }) {
    _sessionStartTime = DateTime.now();
    _lastActivityTime = DateTime.now();
    _onSessionExpiring = onExpiring;
    _onSessionExpired = onExpired;
    _state = SessionState.active;

    // Start periodic check timer
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(seconds: SessionConfig.checkIntervalSeconds),
      (_) => _checkSessionStatus(),
    );

    // Set expiration timer
    _scheduleExpiration();
  }

  /// Update last activity time (call on user interaction)
  void recordActivity() {
    _lastActivityTime = DateTime.now();
    _remainingSeconds = SessionConfig.sessionTimeoutSeconds;
    
    // If was expiring, reset to active
    if (_state == SessionState.expiring) {
      _state = SessionState.active;
    }
  }

  /// Extend session (reset the timeout)
  void extendSession() {
    recordActivity();
    _scheduleExpiration();
  }

  /// End session
  void endSession() {
    _checkTimer?.cancel();
    _expirationTimer?.cancel();
    _state = SessionState.expired;
    _onSessionExpired?.call();
  }

  /// Check session status
  Future<void> _checkSessionStatus() async {
    if (_state == SessionState.expired) return;

    try {
      // Verify session with backend
      final isValid = await _verifySession();
      
      if (!isValid) {
        _handleExpiration();
        return;
      }

      // Update remaining time
      if (_lastActivityTime != null) {
        final elapsed = DateTime.now().difference(_lastActivityTime!).inSeconds;
        _remainingSeconds = SessionConfig.sessionTimeoutSeconds - elapsed;

        if (_remainingSeconds <= 0) {
          _handleExpiration();
        } else if (_remainingSeconds <= SessionConfig.warningThresholdSeconds) {
          _handleExpiring();
        }
      }
    } catch (e) {
      // Network error - don't expire immediately
      debugPrint('Session check failed: $e');
    }
  }

  /// Verify session with backend
  Future<bool> _verifySession() async {
    try {
      final apiClient = ApiClient();
      await apiClient.get('/auth/session');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Schedule expiration
  void _scheduleExpiration() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer(
      const Duration(seconds: SessionConfig.sessionTimeoutSeconds),
      _handleExpiration,
    );
  }

  /// Handle session expiring (within warning period)
  void _handleExpiring() {
    if (_state == SessionState.expiring) return;
    
    _state = SessionState.expiring;
    _onSessionExpiring?.call();
  }

  /// Handle session expiration
  void _handleExpiration() {
    _state = SessionState.expired;
    _checkTimer?.cancel();
    _expirationTimer?.cancel();
    _onSessionExpired?.call();
  }

  /// Format remaining time as MM:SS
  String get formattedRemainingTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Provider for session service
final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService();
});

/// Provider for session state
final sessionStateProvider = StateProvider<SessionState>((ref) {
  return SessionState.active;
});

/// Session timeout dialog widget
class SessionTimeoutDialog extends StatefulWidget {
  final int remainingSeconds;
  final VoidCallback onExtend;
  final VoidCallback onLogout;

  const SessionTimeoutDialog({
    super.key,
    required this.remainingSeconds,
    required this.onExtend,
    required this.onLogout,
  });

  @override
  State<SessionTimeoutDialog> createState() => _SessionTimeoutDialogState();
}

class _SessionTimeoutDialogState extends State<SessionTimeoutDialog> {
  late int _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _seconds = widget.remainingSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 0) {
        setState(() {
          _seconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = _seconds ~/ 60;
    final seconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          const Text('Session Expiring'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your session will expire in',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formattedTime,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Would you like to stay logged in?',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onLogout,
          child: const Text('Log Out'),
        ),
        ElevatedButton(
          onPressed: widget.onExtend,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Stay Logged In'),
        ),
      ],
    );
  }
}

/// Mixin for handling session timeout in screens
mixin SessionTimeoutMixin<T extends ConsumerStatefulWidget> on State<T> {
  SessionService get sessionService => SessionService();
  SessionState get sessionState => sessionService.state;

  void showSessionTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SessionTimeoutDialog(
        remainingSeconds: sessionService.remainingSeconds,
        onExtend: () {
          sessionService.extendSession();
          Navigator.of(context).pop();
        },
        onLogout: () {
          sessionService.endSession();
          Navigator.of(context).pop();
          // Navigate to login
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Listen for session state changes
    sessionService.startSession(
      onExpiring: () {
        if (mounted) showSessionTimeoutDialog();
      },
      onExpired: () {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    // Don't end session here - let it continue globally
    super.dispose();
  }
}
