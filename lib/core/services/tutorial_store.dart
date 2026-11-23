import 'package:shared_preferences/shared_preferences.dart';

import '../utils/utils.dart';

/// Remembers whether a member has been shown the in-app tutorial.
///
/// WHY THIS EXISTS
/// ---------------
/// The tutorial is a walkthrough of the four tabs and the main member actions,
/// shown once after a member first reaches the dashboard. It has to be
/// dismissible and it must never come back on its own — a walkthrough that
/// reappears every launch is worse than none, because members learn to tap
/// through it without reading.
///
/// The flag is keyed by member id, not by device, for the same reason the fee
/// confirmation is: a shared phone must not let one member's "seen it" hide the
/// tutorial from another. And unlike a "has paid" record, an unset flag is
/// harmless — the worst case is that a returning member sees the walkthrough
/// once more, which is why nothing here needs to fail loudly.
class TutorialStore {
  const TutorialStore._();

  static const String _seenPrefix = 'tutorial_seen:';

  static String _key(String userId) => '$_seenPrefix$userId';

  /// Record that [userId] has completed or dismissed the tutorial.
  ///
  /// Deliberately called on *dismiss* as well as on completion: choosing to
  /// skip is a decision to not see it, and asking again next launch would be
  /// nagging.
  static Future<void> markSeen(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(userId), true);
    } catch (e) {
      // Worst case the member sees the walkthrough again next launch. Never
      // block the dashboard on local storage.
      logger.w('Could not record tutorial completion: $e');
    }
  }

  /// Whether [userId] has already seen the tutorial on this device.
  static Future<bool> hasSeen(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(userId)) ?? false;
    } catch (e) {
      logger.w('Could not read tutorial state: $e');
      // Fail towards *showing* it: a member who has not seen it is the common
      // case for a new install, and re-showing is recoverable where silently
      // skipping is not.
      return false;
    }
  }

  /// Forget [userId]'s state so the tutorial can be offered again.
  ///
  /// Used by the "Replay tutorial" action, and on sign-out so the next member
  /// on this device is not treated as having seen it.
  static Future<void> clear(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (e) {
      logger.w('Could not clear tutorial state: $e');
    }
  }
}
