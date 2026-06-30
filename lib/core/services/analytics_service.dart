import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'logger_service.dart';

/// Analytics service for tracking user events
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _isEnabled = false;

  /// Initialize the analytics service
  Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _isEnabled = true;
      logger.info('AnalyticsService initialized');
    } catch (e) {
      logger.error('AnalyticsService initialization failed: $e');
      _isEnabled = false;
    }
  }

  /// Check if analytics is enabled
  bool get isEnabled => _isEnabled;

  /// Log app open event
  Future<void> logAppOpen() async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logAppOpen();
      logger.debug('Analytics: App opened');
    } catch (e) {
      logger.error('Failed to log app open: $e');
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    String? parameters,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClassOverride: screenClass,
        parameters: parameters != null ? {'parameters': parameters} : null,
      );
      logger.debug('Analytics: Screen viewed - $screenName');
    } catch (e) {
      logger.error('Failed to log screen view: $e');
    }
  }

  /// Log user sign in
  Future<void> logSignIn({
    required String signInMethod,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logLogin(
        loginMethod: signInMethod,
      );
      logger.debug('Analytics: User signed in with $signInMethod');
    } catch (e) {
      logger.error('Failed to log sign in: $e');
    }
  }

  /// Log user sign up
  Future<void> logSignUp({
    required String signUpMethod,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logSignUp(
        signUpMethod: signUpMethod,
      );
      logger.debug('Analytics: User signed up with $signUpMethod');
    } catch (e) {
      logger.error('Failed to log sign up: $e');
    }
  }

  /// Log contribution made
  Future<void> logContribution({
    required double amount,
    required String contributionType,
    String? paymentMethod,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logEvent(
        name: 'contribution_made',
        parameters: {
          'amount': amount,
          'contribution_type': contributionType,
          if (paymentMethod != null) 'payment_method': paymentMethod,
        },
      );
      logger.debug('Analytics: Contribution made - ₦$amount ($contributionType)');
    } catch (e) {
      logger.error('Failed to log contribution: $e');
    }
  }

  /// Log loan application
  Future<void> logLoanApplication({
    required double amount,
    required String loanType,
    required int tenure,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logEvent(
        name: 'loan_application',
        parameters: {
          'amount': amount,
          'loan_type': loanType,
          'tenure': tenure,
        },
      );
      logger.debug('Analytics: Loan application - ₦$amount ($loanType, $tenure months)');
    } catch (e) {
      logger.error('Failed to log loan application: $e');
    }
  }

  /// Log loan approved
  Future<void> logLoanApproved({
    required double amount,
    required String loanType,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logEvent(
        name: 'loan_approved',
        parameters: {
          'amount': amount,
          'loan_type': loanType,
        },
      );
      logger.debug('Analytics: Loan approved - ₦$amount ($loanType)');
    } catch (e) {
      logger.error('Failed to log loan approval: $e');
    }
  }

  /// Log KYC completion
  Future<void> logKYCCompleted({
    required String kycType,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logEvent(
        name: 'kyc_completed',
        parameters: {
          'kyc_type': kycType,
        },
      );
      logger.debug('Analytics: KYC completed - $kycType');
    } catch (e) {
      logger.error('Failed to log KYC completion: $e');
    }
  }

  /// Log referral shared
  Future<void> logReferralShared({
    required String referralCode,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logShare(
        contentType: 'referral_code',
        itemId: referralCode,
        shareMethod: 'copy_link',
      );
      logger.debug('Analytics: Referral shared - $referralCode');
    } catch (e) {
      logger.error('Failed to log referral share: $e');
    }
  }

  /// Log search performed
  Future<void> logSearch({
    required String searchTerm,
    String? searchCategory,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logSearch(
        searchTerm: searchTerm,
        numberOfResults: 0,
      );
      logger.debug('Analytics: Search - "$searchTerm"');
    } catch (e) {
      logger.error('Failed to log search: $e');
    }
  }

  /// Log button click
  Future<void> logButtonClick({
    required String buttonName,
    String? screenName,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logEvent(
        name: 'button_click',
        parameters: {
          'button_name': buttonName,
          if (screenName != null) 'screen_name': screenName,
          ...?parameters,
        },
      );
    } catch (e) {
      logger.error('Failed to log button click: $e');
    }
  }

  /// Log form submission
  Future<void> logFormSubmission({
    required String formName,
    bool success = true,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logEvent(
        name: 'form_submission',
        parameters: {
          'form_name': formName,
          'success': success,
        },
      );
      logger.debug('Analytics: Form submitted - $formName (success: $success)');
    } catch (e) {
      logger.error('Failed to log form submission: $e');
    }
  }

  /// Log error
  Future<void> logError({
    required String errorCode,
    String? errorMessage,
    String? screenName,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logEvent(
        name: 'error_occurred',
        parameters: {
          'error_code': errorCode,
          if (errorMessage != null) 'error_message': errorMessage,
          if (screenName != null) 'screen_name': screenName,
        },
      );
      logger.debug('Analytics: Error - $errorCode');
    } catch (e) {
      logger.error('Failed to log error: $e');
    }
  }

  /// Log user engagement duration
  Future<void> logEngagementDuration({
    required Duration duration,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.logEvent(
        name: 'engagement_duration',
        parameters: {
          'duration_seconds': duration.inSeconds,
        },
      );
    } catch (e) {
      logger.error('Failed to log engagement duration: $e');
    }
  }

  /// Set user properties
  Future<void> setUserProperties({
    required String userId,
    String? userType,
    String? membershipStatus,
  }) async {
    if (!_isEnabled) return;
    try {
      await _analytics?.setUserId(userId);
      if (userType != null) {
        await _analytics?.setUserProperty(name: 'user_type', value: userType);
      }
      if (membershipStatus != null) {
        await _analytics?.setUserProperty(
          name: 'membership_status',
          value: membershipStatus,
        );
      }
      logger.debug('Analytics: User properties set');
    } catch (e) {
      logger.error('Failed to set user properties: $e');
    }
  }

  /// Clear user properties (on logout)
  Future<void> clearUserProperties() async {
    if (!_isEnabled) return;
    try {
      await _analytics?.setUserId(null);
      logger.debug('Analytics: User properties cleared');
    } catch (e) {
      logger.error('Failed to clear user properties: $e');
    }
  }
}

/// Provider for analytics service
final analyticsProvider = AnalyticsService();

/// Initialize analytics
Future<void> initializeAnalytics() async {
  await analyticsProvider.initialize();
}
