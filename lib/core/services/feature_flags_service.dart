import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

/// Feature flags service for dynamic feature toggles
class FeatureFlagsService {
  static final FeatureFlagsService _instance = FeatureFlagsService._();
  factory FeatureFlagsService() => _instance;
  FeatureFlagsService._();

  final Map<String, bool> _localFlags = {};
  bool _isInitialized = false;
  FirebaseRemoteConfig? _remoteConfig;

  /// Default feature flags
  static const Map<String, bool> _defaultFlags = {
    'enable_new_onboarding': true,
    'enable_biometric_login': true,
    'enable_loan_application': true,
    'enable_salary_deduction': true,
    'enable_rollover': true,
    'enable_referral': true,
    'enable_savings_goals': true,
    'enable_deposit': true,
    'enable_withdrawal': false,
    'enable_push_notifications': true,
    'enable_analytics': true,
    'enable_crash_reporting': true,
    'minimize_kyc_fields': false,
    'show_tutorial_videos': true,
    'enable_qr_payments': false,
    'enable_international_transfers': false,
    'maintenance_mode': false,
  };

  /// Initialize the feature flags service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load local cache first
      await _loadLocalCache();
      
      // Initialize remote config
      _remoteConfig = FirebaseRemoteConfig.instance;
      await _remoteConfig!.setDefaults(_defaultFlags);
      
      // Fetch remote config
      await _fetchRemoteConfig();
      
      _isInitialized = true;
      logger.info('FeatureFlagsService initialized successfully');
    } catch (e) {
      logger.error('FeatureFlagsService initialization failed: $e');
      // Use local defaults on failure
      _localFlags.addAll(_defaultFlags);
    }
  }

  /// Load cached values from local storage
  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _defaultFlags.keys) {
        _localFlags[key] = prefs.getBool(key) ?? _defaultFlags[key]!;
      }
    } catch (e) {
      logger.error('Failed to load local cache: $e');
      _localFlags.addAll(_defaultFlags);
    }
  }

  /// Fetch remote config from Firebase
  Future<void> _fetchRemoteConfig() async {
    try {
      await _remoteConfig!.fetchAndActivate();
      
      // Update local flags with remote values
      for (final key in _defaultFlags.keys) {
        _localFlags[key] = _remoteConfig!.getBool(key);
      }
      
      // Cache locally
      await _cacheLocally();
      
      logger.info('Remote config fetched and activated');
    } catch (e) {
      logger.error('Failed to fetch remote config: $e');
    }
  }

  /// Cache values locally
  Future<void> _cacheLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _localFlags.entries) {
        await prefs.setBool(entry.key, entry.value);
      }
    } catch (e) {
      logger.error('Failed to cache locally: $e');
    }
  }

  /// Check if a feature is enabled
  bool isEnabled(String featureKey) {
    return _localFlags[featureKey] ?? _defaultFlags[featureKey] ?? false;
  }

  /// Get all feature flags
  Map<String, bool> getAllFlags() {
    return Map.unmodifiable(_localFlags);
  }

  /// Force refresh feature flags
  Future<void> refresh() async {
    await _fetchRemoteConfig();
  }

  /// Override a feature flag locally (for testing)
  void override(String key, bool value) {
    _localFlags[key] = value;
    _cacheLocally();
  }

  /// Check if app is in maintenance mode
  bool get isMaintenanceMode => isEnabled('maintenance_mode');

  /// Get maintenance message
  String get maintenanceMessage {
    try {
      return _remoteConfig?.getString('maintenance_message') ??
             'We are currently undergoing scheduled maintenance. Please check back soon.';
    } catch (e) {
      return 'We are currently undergoing scheduled maintenance. Please check back soon.';
    }
  }

  /// Check if onboarding is enabled
  bool get isNewOnboardingEnabled => isEnabled('enable_new_onboarding');

  /// Check if biometric login is enabled
  bool get isBiometricLoginEnabled => isEnabled('enable_biometric_login');

  /// Check if loan application is enabled
  bool get isLoanApplicationEnabled => isEnabled('enable_loan_application');

  /// Check if salary deduction is enabled
  bool get isSalaryDeductionEnabled => isEnabled('enable_salary_deduction');

  /// Check if rollover feature is enabled
  bool get isRolloverEnabled => isEnabled('enable_rollover');

  /// Check if referral feature is enabled
  bool get isReferralEnabled => isEnabled('enable_referral');

  /// Check if savings goals is enabled
  bool get isSavingsGoalsEnabled => isEnabled('enable_savings_goals');

  /// Check if deposit is enabled
  bool get isDepositEnabled => isEnabled('enable_deposit');

  /// Check if withdrawal is enabled
  bool get isWithdrawalEnabled => isEnabled('enable_withdrawal');

  /// Check if QR payments is enabled
  bool get isQRPaymentsEnabled => isEnabled('enable_qr_payments');
}

/// Provider for feature flags service
final featureFlagsProvider = Provider<FeatureFlagsService>((ref) {
  return FeatureFlagsService();
});

/// Convenience providers for specific features
final isMaintenanceModeProvider = Provider<bool>((ref) {
  final flags = ref.watch(featureFlagsProvider);
  return flags.isMaintenanceMode;
});

final isBiometricLoginEnabledProvider = Provider<bool>((ref) {
  final flags = ref.watch(featureFlagsProvider);
  return flags.isBiometricLoginEnabled;
});

final isLoanApplicationEnabledProvider = Provider<bool>((ref) {
  final flags = ref.watch(featureFlagsProvider);
  return flags.isLoanApplicationEnabled;
});

final isRolloverEnabledProvider = Provider<bool>((ref) {
  final flags = ref.watch(featureFlagsProvider);
  return flags.isRolloverEnabled;
});
