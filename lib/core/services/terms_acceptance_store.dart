import 'package:shared_preferences/shared_preferences.dart';

/// Local hand-off for policy acceptance given on the sign-up screen.
///
/// WHY THIS EXISTS
/// ---------------
/// Sign-up authenticates directly against Supabase, and the shortened
/// onboarding path (sign up -> verify email -> contribution type -> pay) never
/// calls `POST /auth/complete-registration` — that is where terms acceptance
/// was historically written. So acceptance collected on the sign-up screen had
/// no request of its own to travel on: the member could tick "I agree" and the
/// app would record nothing durable.
///
/// The contribution-type step happens after email verification, is
/// authenticated, and does reach the backend, so the acceptance is stashed here
/// at sign-up and attached to that request instead. Stashing also means it
/// survives the email round-trip, which can involve the app being closed and
/// reopened from the verification link.
///
/// This is a hand-off, not the record: the durable copy is written to the KYC
/// record by `POST /kyc/contribution-type`. It is cleared once forwarded.
class TermsAcceptanceStore {
  const TermsAcceptanceStore._();

  static const String _versionKey = 'terms_accepted_version';
  static const String _atKey = 'terms_accepted_at';

  /// Remember that this device's member accepted [version] at [acceptedAt].
  static Future<void> save({
    required String version,
    required DateTime acceptedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_versionKey, version);
      await prefs.setString(_atKey, acceptedAt.toIso8601String());
    } catch (_) {
      // Never block sign-up on local storage.
    }
  }

  /// Pending acceptance, or null when there is nothing to forward.
  static Future<({String version, String acceptedAt})?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getString(_versionKey);
      final at = prefs.getString(_atKey);
      if (version == null || at == null) return null;
      return (version: version, acceptedAt: at);
    } catch (_) {
      return null;
    }
  }

  /// Clear the hand-off once the backend has recorded it, so a later member on
  /// the same device does not inherit the previous acceptance.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_versionKey);
      await prefs.remove(_atKey);
    } catch (_) {
      // Ignore.
    }
  }
}