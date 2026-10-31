import 'package:shared_preferences/shared_preferences.dart';

import '../utils/utils.dart';

/// Remembers that the server has *confirmed* a member's registration fee is
/// settled, so the app does not ask them to pay again when it next starts up
/// without a connection.
///
/// WHY THIS EXISTS
/// ---------------
/// The activation gate asks the server (`GET /app/home-status`) whether the fee
/// is settled, which is the authoritative answer. But on a cold start with no
/// network that request fails, and the gate then had nothing to go on but the
/// cached profile — whose fee flags default to `false`. A member who had paid
/// was therefore shown the ₦5,000 payment screen on any bad connection.
///
/// The asymmetry is the whole point, and it is deliberate:
///
///   - **Settled** is sticky. Once the server says the fee is settled, that is
///     durable — fees are not un-paid. Caching it locally is safe, and it is the
///     only thing that lets a paying member open the app offline without being
///     accused of owing money.
///   - **Unsettled is never cached.** "Not settled" is exactly the claim the
///     server re-check exists to make, so a local record of it would defeat the
///     gate: a member could clear their fee status by going offline. Only the
///     server may conclude that, and only for this session.
///
/// So this store can only ever *prove paid*. It can never prove unpaid, and the
/// gate treats its absence as "unknown", not as "owes money".
///
/// Keyed by member id because a device can be shared between accounts.
class RegistrationFeeStatusStore {
  const RegistrationFeeStatusStore._();

  static const String _settledPrefix = 'registration_fee_settled_confirmed:';

  static String _key(String userId) => '$_settledPrefix$userId';

  /// Record that the server confirmed [userId]'s registration fee is settled.
  static Future<void> markSettled(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(userId), true);
    } catch (e) {
      // Never block the gate on local storage; worst case the member is asked
      // to retry while offline, which is the old behaviour.
      logger.w('Could not cache settled registration fee: $e');
    }
  }

  /// Whether the server has previously confirmed [userId]'s fee is settled.
  ///
  /// A `false` here means "no confirmation on this device", NOT "unpaid".
  static Future<bool> isSettledConfirmed(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(userId)) ?? false;
    } catch (e) {
      logger.w('Could not read cached registration fee status: $e');
      return false;
    }
  }

  /// Forget [userId]'s confirmation, on sign-out or account deletion.
  ///
  /// Clearing on sign-out is what stops the confirmation leaking to the next
  /// member who signs in on this device.
  static Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (e) {
      logger.w('Could not clear cached registration fee status: $e');
    }
  }
}
