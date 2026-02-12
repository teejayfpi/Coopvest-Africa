/// App Configuration
/// Contains all app-level configuration constants

class AppConfig {
  // App Info
  static const String appName = 'Coopvest Africa';
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';

  // API Configuration
  // For local testing on Android Emulator, use 'http://10.0.2.2:8080/api/v1'
  // For local testing on iOS Simulator, use 'http://localhost:8080/api/v1'
  // For physical devices, use your machine's local IP (e.g., 'http://192.168.x.x:8080/api/v1')
  // For production, replace with your actual backend URL
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080/api/v1');
  static const Duration apiTimeout = Duration(seconds: 60);
  static const int maxRetries = 3;

  // Session Configuration
  static const Duration sessionTimeout = Duration(minutes: 30);
  static const Duration tokenRefreshThreshold = Duration(minutes: 5);

  // Loan Configuration
  static const double minLoanAmount = 50000;
  static const double maxLoanAmount = 5000000;
  static const List<int> loanTenures = [3, 6, 12];
  static const double baseInterestRate = 10.0;
  static const int guarantorsRequired = 3;
  static const double maxGuarantorLimit = 5000000;

  // Contribution Configuration
  static const double minContribution = 5000;
  static const double maxContribution = 500000;

  // QR Code Configuration
  static const Duration qrCodeExpiry = Duration(days: 7);
  static const int maxQRScans = 3;

  // Cache Configuration
  static const Duration cacheExpiry = Duration(hours: 24);
  static const int maxCacheSize = 100; // MB

  // Feature Flags
  static const bool enableBiometric = true;
  static const bool enableOfflineMode = true;
  static const bool enableAnalytics = true;
  static const bool enableCrashlytics = true;

  // Pagination
  static const int pageSize = 20;
  static const int maxPages = 100;

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int pinLength = 4;
  static const int maxPinAttempts = 3;

  // Retry Configuration
  static const Duration retryDelay = Duration(seconds: 2);
  static const double retryBackoffMultiplier = 1.5;
  static const Duration maxRetryDelay = Duration(seconds: 30);

  // Network Configuration
  static const bool enableSSLPinning = true;
  static const bool enableRequestLogging = true;
  static const bool enableResponseLogging = true;

  // Security
  static const bool enableJailbreakDetection = true;
  static const bool enableDebuggerDetection = true;
  static const bool enableCodeObfuscation = true;

  // Localization
  static const String defaultLanguage = 'en';
  static const String defaultCurrency = 'NGN';
  static const String defaultCountry = 'NG';

  // Date & Time
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Notification Configuration
  static const Duration notificationTimeout = Duration(seconds: 5);
  static const int maxNotifications = 50;

  // Analytics Events
  static const String eventAppLaunched = 'app_launched';
  static const String eventUserRegistered = 'user_registered';
  static const String eventUserLoggedIn = 'user_logged_in';
  static const String eventLoanApplied = 'loan_applied';
  static const String eventGuarantorApproved = 'guarantor_approved';
  static const String eventContributionMade = 'contribution_made';
  static const String eventInvestmentParticipated = 'investment_participated';
}
