import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool autoLockEnabled;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool transactionAlerts;
  final bool loanUpdates;
  final bool savingsUpdates;
  final bool promotionalOffers;
  final bool securityAlerts;

  const AppSettings({
    this.autoLockEnabled = true,
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.transactionAlerts = true,
    this.loanUpdates = true,
    this.savingsUpdates = true,
    this.promotionalOffers = false,
    this.securityAlerts = true,
  });

  AppSettings copyWith({
    bool? autoLockEnabled,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? transactionAlerts,
    bool? loanUpdates,
    bool? savingsUpdates,
    bool? promotionalOffers,
    bool? securityAlerts,
  }) {
    return AppSettings(
      autoLockEnabled: autoLockEnabled ?? this.autoLockEnabled,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      transactionAlerts: transactionAlerts ?? this.transactionAlerts,
      loanUpdates: loanUpdates ?? this.loanUpdates,
      savingsUpdates: savingsUpdates ?? this.savingsUpdates,
      promotionalOffers: promotionalOffers ?? this.promotionalOffers,
      securityAlerts: securityAlerts ?? this.securityAlerts,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _keyAutoLock = 'settings_auto_lock';
  static const _keyPush = 'settings_push_notif';
  static const _keyEmail = 'settings_email_notif';
  static const _keySms = 'settings_sms_notif';
  static const _keyTransaction = 'settings_transaction_alerts';
  static const _keyLoan = 'settings_loan_updates';
  static const _keySavings = 'settings_savings_updates';
  static const _keyPromo = 'settings_promo_offers';
  static const _keySecurity = 'settings_security_alerts';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      autoLockEnabled: prefs.getBool(_keyAutoLock) ?? true,
      pushNotifications: prefs.getBool(_keyPush) ?? true,
      emailNotifications: prefs.getBool(_keyEmail) ?? true,
      smsNotifications: prefs.getBool(_keySms) ?? false,
      transactionAlerts: prefs.getBool(_keyTransaction) ?? true,
      loanUpdates: prefs.getBool(_keyLoan) ?? true,
      savingsUpdates: prefs.getBool(_keySavings) ?? true,
      promotionalOffers: prefs.getBool(_keyPromo) ?? false,
      securityAlerts: prefs.getBool(_keySecurity) ?? true,
    );
  }

  Future<void> _save(SharedPreferences prefs) async {
    await prefs.setBool(_keyAutoLock, state.autoLockEnabled);
    await prefs.setBool(_keyPush, state.pushNotifications);
    await prefs.setBool(_keyEmail, state.emailNotifications);
    await prefs.setBool(_keySms, state.smsNotifications);
    await prefs.setBool(_keyTransaction, state.transactionAlerts);
    await prefs.setBool(_keyLoan, state.loanUpdates);
    await prefs.setBool(_keySavings, state.savingsUpdates);
    await prefs.setBool(_keyPromo, state.promotionalOffers);
    await prefs.setBool(_keySecurity, state.securityAlerts);
  }

  Future<void> setAutoLock(bool value) async {
    state = state.copyWith(autoLockEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoLock, value);
  }

  Future<void> setPushNotifications(bool value) async {
    state = state.copyWith(pushNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPush, value);
  }

  Future<void> setEmailNotifications(bool value) async {
    state = state.copyWith(emailNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmail, value);
  }

  Future<void> setSmsNotifications(bool value) async {
    state = state.copyWith(smsNotifications: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySms, value);
  }

  Future<void> setTransactionAlerts(bool value) async {
    state = state.copyWith(transactionAlerts: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTransaction, value);
  }

  Future<void> setLoanUpdates(bool value) async {
    state = state.copyWith(loanUpdates: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoan, value);
  }

  Future<void> setSavingsUpdates(bool value) async {
    state = state.copyWith(savingsUpdates: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySavings, value);
  }

  Future<void> setPromotionalOffers(bool value) async {
    state = state.copyWith(promotionalOffers: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPromo, value);
  }

  Future<void> setSecurityAlerts(bool value) async {
    state = state.copyWith(securityAlerts: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecurity, value);
  }

  Future<void> saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);
