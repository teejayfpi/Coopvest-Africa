import 'package:shared_preferences/shared_preferences.dart';

/// Local record of "this member has submitted KYC".
///
/// AuthGuard decides on every app start whether to force the KYC flow, based
/// on a live `GET /kyc/status` fetch. A transient backend failure — or a
/// successful response whose payload doesn't map to a recognized lifecycle
/// status (status comes back null and defaults to 'pending') — makes the
/// guard believe the member never submitted and throws them back into the KYC
/// flow, even the day after they completed it.
///
/// This cache is the durable source of truth for the gate: it is written the
/// moment KYC is submitted locally (and whenever any successful status fetch
/// confirms a submitted lifecycle status), and AuthGuard trusts it without
/// re-asking the network. Entries are keyed per user so signing out and into
/// a different account on the same device does not inherit the previous
/// member's KYC state.
class KycSubmittedCache {
  static const String _prefix = 'kyc_submitted_';

  /// Lifecycle statuses that mean the member has submitted KYC at least once.
  static const Set<String> submittedStatuses = {
    'submitted',
    'in_review',
    'verified',
    'approved',
    'rejected',
  };

  static String _key(String userId) => '$_prefix$userId';

  static Future<bool> isSubmitted(String userId) async {
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  static Future<void> markSubmitted(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }

  static Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
