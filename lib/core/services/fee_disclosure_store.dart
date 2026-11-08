import 'package:shared_preferences/shared_preferences.dart';

import '../utils/utils.dart';

/// Remembers which revision of the published fee schedule this device has
/// already put in front of the member.
///
/// WHY THIS EXISTS
/// ---------------
/// The disclosure is shown once, at first open, before registration. "Once"
/// has to mean *once per revision*, not *once ever*: if a charge changes and
/// the member never sees the new price, the disclosure has done the opposite of
/// its job. So what is recorded is the schedule hash the member was shown, and
/// the disclosure is shown again whenever the server's hash differs.
///
/// A bundled schedule carries no hash. It is shown but *not* recorded, so the
/// real schedule supersedes it as soon as the member is online rather than
/// being suppressed by it. That is the intended direction: bundled text is a
/// stopgap, not a substitute for the published price list.
///
/// The record is device-wide, not per member. The price list is public and
/// identical for everyone, so there is nothing to keep apart between accounts,
/// and re-showing it to the same person after a re-login would be friction with
/// no disclosure benefit.
class FeeDisclosureStore {
  const FeeDisclosureStore._();

  static const String _shownHashKey = 'fee_disclosure_shown_hash';
  static const String _shownAtKey = 'fee_disclosure_shown_at';

  /// The schedule hash last shown, or null when nothing has been shown.
  static Future<String?> shownHash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_shownHashKey);
    } catch (e) {
      logger.w('Could not read shown fee disclosure hash: $e');
      return null;
    }
  }

  /// When the disclosure was last shown, for support and diagnostics.
  static Future<DateTime?> shownAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_shownAtKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (e) {
      logger.w('Could not read shown fee disclosure time: $e');
      return null;
    }
  }

  /// Whether a schedule with [hash] still needs to be shown.
  ///
  /// An empty [hash] is a bundled schedule; it is never treated as "already
  /// shown" against a real server hash, so the live schedule supersedes it.
  static Future<bool> needsShowing(String hash) async {
    if (hash.isEmpty) return true;
    final shown = await shownHash();
    return shown != hash;
  }

  /// Record that a schedule with [hash] has been put in front of the member.
  static Future<void> markShown(String hash, {DateTime? at}) async {
    if (hash.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_shownHashKey, hash);
      await prefs.setString(_shownAtKey, (at ?? DateTime.now()).toIso8601String());
    } catch (e) {
      logger.w('Could not record shown fee disclosure: $e');
    }
  }
}
