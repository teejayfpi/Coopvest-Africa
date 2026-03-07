# Coopvest Africa Mobile App - Technical Architecture

**Version:** 1.0  
**Date:** December 2025  
**Platform:** Flutter (iOS & Android)  
**Backend:** Firebase / Airtable compatible

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Technology Stack](#technology-stack)
3. [State Management](#state-management)
4. [API Integration](#api-integration)
5. [Security Architecture](#security-architecture)
6. [Local Storage & Caching](#local-storage--caching)
7. [Offline-First Strategy](#offline-first-strategy)
8. [Database Schema](#database-schema)
9. [Error Handling](#error-handling)
10. [Performance Optimization](#performance-optimization)

---

## Project Structure

```
coopvest_mobile/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── config/
│   │   ├── app_config.dart               # App configuration
│   │   ├── api_config.dart               # API endpoints
│   │   ├── theme_config.dart             # Theme configuration
│   │   └── constants.dart                # App constants
│   │
│   ├── core/
│   │   ├── errors/
│   │   │   ├── exceptions.dart           # Custom exceptions
│   │   │   └── failures.dart             # Failure handling
│   │   ├── network/
│   │   │   ├── network_info.dart         # Network connectivity
│   │   │   ├── api_client.dart           # HTTP client
│   │   │   └── interceptors.dart         # Request/response interceptors
│   │   ├── security/
│   │   │   ├── encryption_service.dart   # Data encryption
│   │   │   ├── biometric_service.dart    # Biometric auth
│   │   │   ├── session_manager.dart      # Session management
│   │   │   └── secure_storage.dart       # Secure key storage
│   │   ├── storage/
│   │   │   ├── local_storage.dart        # Local database
│   │   │   ├── cache_manager.dart        # Cache management
│   │   │   └── preferences.dart          # Shared preferences
│   │   └── utils/
│   │       ├── logger.dart               # Logging utility
│   │       ├── validators.dart           # Input validation
│   │       ├── formatters.dart           # Data formatting
│   │       └── extensions.dart           # Dart extensions
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── remote/
│   │   │   │   ├── auth_remote_datasource.dart
│   │   │   │   ├── wallet_remote_datasource.dart
│   │   │   │   ├── loan_remote_datasource.dart
│   │   │   │   ├── investment_remote_datasource.dart
│   │   │   │   └── user_remote_datasource.dart
│   │   │   └── local/
│   │   │       ├── auth_local_datasource.dart
│   │   │       ├── wallet_local_datasource.dart
│   │   │       ├── loan_local_datasource.dart
│   │   │       ├── investment_local_datasource.dart
│   │   │       └── user_local_datasource.dart
│   │   ├── models/
│   │   │   ├── auth/
│   │   │   │   ├── user_model.dart
│   │   │   │   ├── login_request.dart
│   │   │   │   └── auth_response.dart
│   │   │   ├── wallet/
│   │   │   │   ├── wallet_model.dart
│   │   │   │   ├── transaction_model.dart
│   │   │   │   └── contribution_model.dart
│   │   │   ├── loan/
│   │   │   │   ├── loan_model.dart
│   │   │   │   ├── guarantor_model.dart
│   │   │   │   └── loan_application_model.dart
│   │   │   ├── investment/
│   │   │   │   ├── investment_model.dart
│   │   │   │   ├── project_model.dart
│   │   │   │   └── participation_model.dart
│   │   │   └── common/
│   │   │       ├── api_response.dart
│   │   │       └── pagination.dart
│   │   └── repositories/
│   │       ├── auth_repository.dart
│   │       ├── wallet_repository.dart
│   │       ├── loan_repository.dart
│   │       ├── investment_repository.dart
│   │       └── user_repository.dart
│   │
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── auth/
│   │   │   │   ├── user.dart
│   │   │   │   └── auth_response.dart
│   │   │   ├── wallet/
│   │   │   │   ├── wallet.dart
│   │   │   │   ├── transaction.dart
│   │   │   │   └── contribution.dart
│   │   │   ├── loan/
│   │   │   │   ├── loan.dart
│   │   │   │   ├── guarantor.dart
│   │   │   │   └── loan_application.dart
│   │   │   ├── investment/
│   │   │   │   ├── investment.dart
│   │   │   │   ├── project.dart
│   │   │   │   └── participation.dart
│   │   │   └── common/
│   │   │       └── pagination.dart
│   │   └── usecases/
│   │       ├── auth/
│   │       │   ├── login_usecase.dart
│   │       │   ├── register_usecase.dart
│   │       │   ├── logout_usecase.dart
│   │       │   └── verify_kyc_usecase.dart
│   │       ├── wallet/
│   │       │   ├── get_wallet_usecase.dart
│   │       │   ├── make_contribution_usecase.dart
│   │       │   ├── get_transactions_usecase.dart
│   │       │   └── generate_statement_usecase.dart
│   │       ├── loan/
│   │       │   ├── apply_loan_usecase.dart
│   │       │   ├── get_guarantor_requests_usecase.dart
│   │       │   ├── approve_guarantor_usecase.dart
│   │       │   ├── get_loan_status_usecase.dart
│   │       │   └── repay_loan_usecase.dart
│   │       ├── investment/
│   │       │   ├── get_projects_usecase.dart
│   │       │   ├── participate_investment_usecase.dart
│   │       │   ├── get_investments_usecase.dart
│   │       │   └── get_project_details_usecase.dart
│   │       └── user/
│   │           ├── get_profile_usecase.dart
│   │           ├── update_profile_usecase.dart
│   │           └── setup_biometric_usecase.dart
│   │
│   ├── presentation/
│   │   ├── providers/
│   │   │   ├── auth_provider.dart
│   │   │   ├── wallet_provider.dart
│   │   │   ├── loan_provider.dart
│   │   │   ├── investment_provider.dart
│   │   │   ├── user_provider.dart
│   │   │   ├── connectivity_provider.dart
│   │   │   └── notification_provider.dart
│   │   ├── widgets/
│   │   │   ├── common/
│   │   │   │   ├── app_button.dart
│   │   │   │   ├── app_card.dart
│   │   │   │   ├── app_input.dart
│   │   │   │   ├── app_modal.dart
│   │   │   │   ├── app_loader.dart
│   │   │   │   ├── app_error.dart
│   │   │   │   ├── app_empty.dart
│   │   │   │   ├── app_snackbar.dart
│   │   │   │   └── app_bottom_sheet.dart
│   │   │   ├── navigation/
│   │   │   │   ├── bottom_nav_bar.dart
│   │   │   │   ├── app_bar.dart
│   │   │   │   └── drawer.dart
│   │   │   └── custom/
│   │   │       ├── qr_scanner.dart
│   │   │       ├── qr_generator.dart
│   │   │       ├── balance_card.dart
│   │   │       ├── transaction_item.dart
│   │   │       ├── loan_card.dart
│   │   │       ├── investment_card.dart
│   │   │       └── guarantor_card.dart
│   │   ├── screens/
│   │   │   ├── splash/
│   │   │   │   └── splash_screen.dart
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   ├── kyc_screen.dart
│   │   │   │   ├── biometric_setup_screen.dart
│   │   │   │   └── password_recovery_screen.dart
│   │   │   ├── onboarding/
│   │   │   │   ├── onboarding_screen.dart
│   │   │   │   └── welcome_screens.dart
│   │   │   ├── home/
│   │   │   │   ├── home_screen.dart
│   │   │   │   ├── dashboard_screen.dart
│   │   │   │   └── alerts_screen.dart
│   │   │   ├── wallet/
│   │   │   │   ├── wallet_screen.dart
│   │   │   │   ├── contribution_screen.dart
│   │   │   │   ├── transaction_history_screen.dart
│   │   │   │   └── statement_screen.dart
│   │   │   ├── loans/
│   │   │   │   ├── loans_screen.dart
│   │   │   │   ├── loan_application_screen.dart
│   │   │   │   ├── get_guarantors_screen.dart
│   │   │   │   ├── guarantor_request_screen.dart
│   │   │   │   ├── loan_details_screen.dart
│   │   │   │   └── repayment_screen.dart
│   │   │   ├── investments/
│   │   │   │   ├── investments_screen.dart
│   │   │   │   ├── projects_screen.dart
│   │   │   │   ├── project_details_screen.dart
│   │   │   │   ├── participate_screen.dart
│   │   │   │   └── investment_details_screen.dart
│   │   │   ├── profile/
│   │   │   │   ├── profile_screen.dart
│   │   │   │   ├── edit_profile_screen.dart
│   │   │   │   ├── kyc_status_screen.dart
│   │   │   │   ├── security_settings_screen.dart
│   │   │   │   ├── device_management_screen.dart
│   │   │   │   ├── notification_preferences_screen.dart
│   │   │   │   ├── help_screen.dart
│   │   │   │   └── about_screen.dart
│   │   │   └── common/
│   │   │       ├── qr_scanner_screen.dart
│   │   │       ├── notification_center_screen.dart
│   │   │       └── search_screen.dart
│   │   └── pages/
│   │       └── main_page.dart
│   │
│   └── service_locator.dart               # Dependency injection
│
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── pubspec.yaml                           # Dependencies
├── analysis_options.yaml                  # Linting rules
└── README.md                              # Documentation
```

---

## Technology Stack

### Core Framework
- **Flutter:** 3.16+ (latest stable)
- **Dart:** 3.2+

### State Management
- **Riverpod:** 2.4+ (recommended for scalability)
  - `flutter_riverpod` - Core state management
  - `riverpod_generator` - Code generation
  - Alternative: `Provider` 6.0+ (simpler projects)

### Networking & API
- **Dio:** 5.3+ (HTTP client with interceptors)
- **Retrofit:** 4.0+ (Type-safe API client)
- **JSON Serialization:** `json_serializable` + `build_runner`

### Local Storage
- **SQLite:** `sqflite` 2.3+ (Relational database)
- **Hive:** 2.2+ (Fast key-value store, alternative)
- **Shared Preferences:** `shared_preferences` 2.2+ (Simple key-value)
- **Secure Storage:** `flutter_secure_storage` 9.0+ (Encrypted storage)

### Security
- **Biometric Authentication:** `local_auth` 2.1+
- **Encryption:** `encrypt` 5.0+ (AES encryption)
- **JWT Handling:** `dart_jsonwebtoken` 2.12+
- **SSL Pinning:** `dio` with custom certificates

### QR Code
- **QR Generation:** `qr_flutter` 4.0+
- **QR Scanning:** `mobile_scanner` 3.5+ (modern, performant)
- **Alternative:** `qr_code_scanner` (legacy)

### Notifications
- **Firebase Cloud Messaging:** `firebase_messaging` 14.6+
- **Local Notifications:** `flutter_local_notifications` 16.1+

### UI & Design
- **Material Design 3:** Built-in Flutter
- **Animations:** `flutter_animate` 4.2+ (optional, for complex animations)
- **Icons:** `flutter_svg` 2.0+ (SVG support)

### Firebase Services (Optional)
- **Firebase Core:** `firebase_core` 2.24+
- **Firebase Auth:** `firebase_auth` 4.10+
- **Firebase Firestore:** `cloud_firestore` 4.13+
- **Firebase Storage:** `firebase_storage` 11.2+
- **Firebase Analytics:** `firebase_analytics` 10.4+
- **Firebase Crashlytics:** `firebase_crashlytics` 3.3+

### Development Tools
- **Code Generation:** `build_runner` 2.4+
- **Linting:** `flutter_lints` 2.0+
- **Testing:** `mockito` 5.4+, `mocktail` 1.0+
- **Logging:** `logger` 2.0+

### Device Features
- **Camera:** `camera` 0.10+ (for KYC selfie)
- **Image Picker:** `image_picker` 1.0+
- **File Handling:** `file_picker` 6.0+
- **Device Info:** `device_info_plus` 9.0+
- **Connectivity:** `connectivity_plus` 5.0+

### Utilities
- **Date/Time:** `intl` 0.19+
- **Environment Variables:** `flutter_dotenv` 5.1+
- **URL Launcher:** `url_launcher` 6.1+
- **Share:** `share_plus` 7.0+

---

## State Management

### Riverpod Architecture

```dart
// 1. Define State Notifiers
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authRepository) : super(const AuthState.initial());
  
  final AuthRepository _authRepository;
  
  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    final result = await _authRepository.login(email, password);
    result.fold(
      (failure) => state = AuthState.error(failure.message),
      (user) => state = AuthState.authenticated(user),
    );
  }
}

// 2. Create Providers
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository);
});

// 3. Use in Widgets
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return authState.when(
      initial: () => _buildLoginForm(context, ref),
      loading: () => const LoadingScreen(),
      authenticated: (user) => const HomeScreen(),
      error: (message) => ErrorScreen(message: message),
    );
  }
}
```

### State Classes

```dart
// Auth State
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(User user) = _Authenticated;
  const factory AuthState.error(String message) = _Error;
}

// Wallet State
@freezed
class WalletState with _$WalletState {
  const factory WalletState.initial() = _Initial;
  const factory WalletState.loading() = _Loading;
  const factory WalletState.loaded(Wallet wallet) = _Loaded;
  const factory WalletState.error(String message) = _Error;
}

// Loan State
@freezed
class LoanState with _$LoanState {
  const factory LoanState.initial() = _Initial;
  const factory LoanState.loading() = _Loading;
  const factory LoanState.loaded(List<Loan> loans) = _Loaded;
  const factory LoanState.error(String message) = _Error;
}
```

---

## API Integration

### API Client Configuration

```dart
class ApiClient {
  static const String baseUrl = 'https://api.coopvest.com/v1';
  static const Duration timeout = Duration(seconds: 30);
  
  late Dio _dio;
  
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    // Add interceptors
    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(LoggingInterceptor());
    _dio.interceptors.add(ErrorInterceptor());
    
    // SSL Pinning
    _setupSSLPinning();
  }
  
  void _setupSSLPinning() {
    // Implement certificate pinning
  }
}
```

### API Endpoints

```dart
class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String verifyKyc = '/auth/verify-kyc';
  static const String refreshToken = '/auth/refresh-token';
  
  // Wallet
  static const String getWallet = '/wallet';
  static const String makeContribution = '/wallet/contribute';
  static const String getTransactions = '/wallet/transactions';
  static const String generateStatement = '/wallet/statement';
  
  // Loans
  static const String applyLoan = '/loans/apply';
  static const String getLoans = '/loans';
  static const String getLoanDetails = '/loans/{id}';
  static const String getGuarantorRequests = '/loans/guarantor-requests';
  static const String approveGuarantor = '/loans/{id}/approve-guarantor';
  static const String repayLoan = '/loans/{id}/repay';
  
  // Investments
  static const String getProjects = '/investments/projects';
  static const String getProjectDetails = '/investments/projects/{id}';
  static const String participateInvestment = '/investments/participate';
  static const String getInvestments = '/investments';
  
  // User
  static const String getProfile = '/user/profile';
  static const String updateProfile = '/user/profile';
  static const String setupBiometric = '/user/biometric';
}
```

### Request/Response Models

```dart
// Login Request
@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;
  final String? deviceId;
  
  LoginRequest({
    required this.email,
    required this.password,
    this.deviceId,
  });
  
  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

// API Response Wrapper
@JsonSerializable()
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final String? error;
  
  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });
  
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);
}
```

---

## Security Architecture

### Authentication Flow

```dart
class AuthService {
  final SecureStorage _secureStorage;
  final ApiClient _apiClient;
  
  // Login with credentials
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: LoginRequest(email: email, password: password),
      );
      
      final authResponse = AuthResponse.fromJson(response.data);
      
      // Store tokens securely
      await _secureStorage.saveToken(authResponse.accessToken);
      await _secureStorage.saveRefreshToken(authResponse.refreshToken);
      
      // Bind to device
      await _bindToDevice();
      
      return authResponse;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }
  
  // Biometric authentication
  Future<bool> authenticateWithBiometric() async {
    try {
      final isAuthenticated = await LocalAuthentication().authenticate(
        localizedReason: 'Authenticate to access Coopvest',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      if (isAuthenticated) {
        // Retrieve stored token
        final token = await _secureStorage.getToken();
        return token != null;
      }
      return false;
    } catch (e) {
      throw BiometricException(e.toString());
    }
  }
  
  // Device binding
  Future<void> _bindToDevice() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final deviceId = deviceInfo.id;
    
    await _secureStorage.saveDeviceId(deviceId);
  }
  
  // Session management
  Future<void> validateSession() async {
    final token = await _secureStorage.getToken();
    final deviceId = await _secureStorage.getDeviceId();
    
    if (token == null || deviceId == null) {
      throw SessionExpiredException();
    }
    
    // Verify token validity
    final isValid = _verifyToken(token);
    if (!isValid) {
      await refreshToken();
    }
  }
  
  // Token refresh
  Future<void> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      
      final response = await _apiClient.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      
      final newToken = response.data['accessToken'];
      await _secureStorage.saveToken(newToken);
    } catch (e) {
      throw TokenRefreshException(e.toString());
    }
  }
}
```

### Encryption Service

```dart
class EncryptionService {
  late final Encrypter _encrypter;
  late final IV _iv;
  
  EncryptionService() {
    final key = Key.fromSecureRandom(32); // 256-bit key
    _iv = IV.fromSecureRandom(16);
    _encrypter = Encrypter(AES(key));
  }
  
  String encrypt(String plaintext) {
    final encrypted = _encrypter.encrypt(plaintext, iv: _iv);
    return encrypted.base64;
  }
  
  String decrypt(String ciphertext) {
    final encrypted = Encrypted.fromBase64(ciphertext);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }
}
```

### Secure Storage

```dart
class SecureStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }
  
  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }
  
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: 'refresh_token', value: token);
  }
  
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }
  
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
```

---

## Local Storage & Caching

### SQLite Database Schema

```dart
class DatabaseHelper {
  static const String dbName = 'coopvest.db';
  static const int dbVersion = 1;
  
  // Tables
  static const String usersTable = 'users';
  static const String walletsTable = 'wallets';
  static const String transactionsTable = 'transactions';
  static const String loansTable = 'loans';
  static const String guarantorsTable = 'guarantors';
  static const String investmentsTable = 'investments';
  
  // Create tables
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $usersTable (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        name TEXT,
        phone TEXT,
        kyc_status TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $walletsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        balance REAL,
        total_contributions REAL,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $transactionsTable (
        id TEXT PRIMARY KEY,
        wallet_id TEXT,
        type TEXT,
        amount REAL,
        status TEXT,
        created_at TEXT,
        FOREIGN KEY (wallet_id) REFERENCES $walletsTable(id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $loansTable (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        amount REAL,
        tenure INTEGER,
        status TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $guarantorsTable (
        id TEXT PRIMARY KEY,
        loan_id TEXT,
        guarantor_id TEXT,
        status TEXT,
        created_at TEXT,
        FOREIGN KEY (loan_id) REFERENCES $loansTable(id),
        FOREIGN KEY (guarantor_id) REFERENCES $usersTable(id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $investmentsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        project_id TEXT,
        amount REAL,
        status TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id)
      )
    ''');
  }
}
```

### Cache Manager

```dart
class CacheManager {
  final Database _db;
  static const Duration cacheExpiry = Duration(hours: 24);
  
  Future<T?> get<T>(String key) async {
    try {
      final result = await _db.query(
        'cache',
        where: 'key = ? AND expires_at > ?',
        whereArgs: [key, DateTime.now().toIso8601String()],
      );
      
      if (result.isNotEmpty) {
        return jsonDecode(result.first['value'] as String) as T;
      }
    } catch (e) {
      logger.e('Cache get error: $e');
    }
    return null;
  }
  
  Future<void> set<T>(String key, T value) async {
    try {
      await _db.insert(
        'cache',
        {
          'key': key,
          'value': jsonEncode(value),
          'expires_at': DateTime.now().add(cacheExpiry).toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      logger.e('Cache set error: $e');
    }
  }
  
  Future<void> clear() async {
    await _db.delete('cache');
  }
}
```

---

## Offline-First Strategy

### Sync Manager

```dart
class SyncManager {
  final Database _db;
  final ApiClient _apiClient;
  
  // Queue offline actions
  Future<void> queueAction(OfflineAction action) async {
    await _db.insert('offline_queue', {
      'id': action.id,
      'type': action.type,
      'data': jsonEncode(action.data),
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }
  
  // Sync when online
  Future<void> syncOfflineActions() async {
    final result = await _db.query(
      'offline_queue',
      where: 'synced = 0',
    );
    
    for (final row in result) {
      try {
        final action = OfflineAction.fromMap(row);
        await _syncAction(action);
        
        // Mark as synced
        await _db.update(
          'offline_queue',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [action.id],
        );
      } catch (e) {
        logger.e('Sync error: $e');
      }
    }
  }
  
  Future<void> _syncAction(OfflineAction action) async {
    switch (action.type) {
      case 'contribution':
        await _apiClient.post(
          ApiEndpoints.makeContribution,
          data: action.data,
        );
        break;
      case 'loan_application':
        await _apiClient.post(
          ApiEndpoints.applyLoan,
          data: action.data,
        );
        break;
      // ... other action types
    }
  }
}
```

### Offline Data Access

```dart
class OfflineDataProvider {
  final Database _db;
  final CacheManager _cacheManager;
  
  // Get wallet (from cache or local DB)
  Future<Wallet?> getWallet(String userId) async {
    // Try cache first
    var wallet = await _cacheManager.get<Wallet>('wallet_$userId');
    if (wallet != null) return wallet;
    
    // Try local database
    final result = await _db.query(
      'wallets',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    
    if (result.isNotEmpty) {
      return Wallet.fromMap(result.first);
    }
    
    return null;
  }
  
  // Get transactions (from local DB)
  Future<List<Transaction>> getTransactions(String walletId) async {
    final result = await _db.query(
      'transactions',
      where: 'wallet_id = ?',
      whereArgs: [walletId],
      orderBy: 'created_at DESC',
    );
    
    return result.map((row) => Transaction.fromMap(row)).toList();
  }
}
```

---

## Database Schema

### Complete Schema

```sql
-- Users Table
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  phone TEXT UNIQUE,
  name TEXT NOT NULL,
  date_of_birth TEXT,
  gender TEXT,
  occupation TEXT,
  kyc_status TEXT DEFAULT 'pending',
  kyc_submitted_at TEXT,
  kyc_approved_at TEXT,
  id_type TEXT,
  id_number TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  country TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Wallets Table
CREATE TABLE wallets (
  id TEXT PRIMARY KEY,
  user_id TEXT UNIQUE NOT NULL,
  balance REAL DEFAULT 0,
  total_contributions REAL DEFAULT 0,
  pending_contributions REAL DEFAULT 0,
  available_for_withdrawal REAL DEFAULT 0,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Transactions Table
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  wallet_id TEXT NOT NULL,
  type TEXT NOT NULL,
  amount REAL NOT NULL,
  status TEXT DEFAULT 'pending',
  description TEXT,
  reference_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (wallet_id) REFERENCES wallets(id)
);

-- Loans Table
CREATE TABLE loans (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  amount REAL NOT NULL,
  tenure INTEGER NOT NULL,
  interest_rate REAL,
  monthly_repayment REAL,
  total_repayment REAL,
  status TEXT DEFAULT 'draft',
  purpose TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Guarantors Table
CREATE TABLE guarantors (
  id TEXT PRIMARY KEY,
  loan_id TEXT NOT NULL,
  guarantor_id TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  accepted_at TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (loan_id) REFERENCES loans(id),
  FOREIGN KEY (guarantor_id) REFERENCES users(id)
);

-- Investments Table
CREATE TABLE investments (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  project_id TEXT NOT NULL,
  amount REAL NOT NULL,
  status TEXT DEFAULT 'active',
  expected_return REAL,
  actual_return REAL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Projects Table
CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  target_amount REAL NOT NULL,
  current_raised REAL DEFAULT 0,
  expected_roi REAL,
  timeline TEXT,
  status TEXT DEFAULT 'active',
  created_at TEXT NOT NULL
);

-- Cache Table
CREATE TABLE cache (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

-- Offline Queue Table
CREATE TABLE offline_queue (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  data TEXT NOT NULL,
  created_at TEXT NOT NULL,
  synced INTEGER DEFAULT 0
);
```

---

## Error Handling

### Custom Exceptions

```dart
abstract class AppException implements Exception {
  final String message;
  AppException(this.message);
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message);
}

class AuthException extends AppException {
  AuthException(String message) : super(message);
}

class ValidationException extends AppException {
  ValidationException(String message) : super(message);
}

class ServerException extends AppException {
  final int? statusCode;
  ServerException(String message, {this.statusCode}) : super(message);
}

class CacheException extends AppException {
  CacheException(String message) : super(message);
}

class BiometricException extends AppException {
  BiometricException(String message) : super(message);
}

class SessionExpiredException extends AppException {
  SessionExpiredException() : super('Session expired. Please login again.');
}

class TokenRefreshException extends AppException {
  TokenRefreshException(String message) : super(message);
}
```

### Error Interceptor

```dart
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String message = 'An error occurred';
    
    if (err.response != null) {
      final statusCode = err.response!.statusCode;
      final data = err.response!.data;
      
      switch (statusCode) {
        case 400:
          message = data['message'] ?? 'Bad request';
          break;
        case 401:
          message = 'Unauthorized. Please login again.';
          break;
        case 403:
          message = 'Access forbidden';
          break;
        case 404:
          message = 'Resource not found';
          break;
        case 500:
          message = 'Server error. Please try again later.';
          break;
        default:
          message = 'An error occurred';
      }
    } else if (err.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout. Please check your internet.';
    } else if (err.type == DioExceptionType.receiveTimeout) {
      message = 'Request timeout. Please try again.';
    }
    
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        message: message,
        error: err.error,
      ),
    );
  }
}
```

---

## Performance Optimization

### Image Optimization

```dart
class ImageOptimizer {
  static ImageProvider optimizeImage(String url) {
    return CachedNetworkImageProvider(
      url,
      cacheManager: CacheManager.instance,
      maxHeight: 1080,
      maxWidth: 1080,
    );
  }
}
```

### List Performance

```dart
class OptimizedListView extends StatelessWidget {
  final List<Item> items;
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ItemTile(item: items[index]);
      },
      // Enable caching
      cacheExtent: 500,
      // Lazy loading
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
    );
  }
}
```

### Memory Management

```dart
class MemoryOptimizer {
  // Clear cache periodically
  static Future<void> clearOldCache() async {
    final cacheDir = await getTemporaryDirectory();
    final files = cacheDir.listSync();
    
    for (final file in files) {
      if (file is File) {
        final stat = file.statSync();
        final age = DateTime.now().difference(stat.modified);
        
        if (age.inDays > 7) {
          file.deleteSync();
        }
      }
    }
  }
}
```

---

## Next Steps

1. **Set up Flutter project** with all dependencies
2. **Implement authentication** with biometric support
3. **Create database schema** and local storage
4. **Build API integration** layer
5. **Implement state management** with Riverpod
6. **Create UI components** and screens
7. **Add offline support** and sync manager
8. **Implement notifications** system
9. **Add security features** (encryption, SSL pinning)
10. **Performance testing** and optimization

