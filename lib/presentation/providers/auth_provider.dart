import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';
import '../../data/models/auth_models.dart';
import '../../data/models/kyc_models.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final ApiClient _apiClient;

  AuthNotifier(this._authRepository, this._apiClient) : super(const AuthState());

  /// Google Sign-In
  Future<void> googleSignIn(String idToken) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _authRepository.googleSignIn(
        idToken: idToken,
      );

      // Set auth token in ApiClient for subsequent API calls
      _apiClient.setAuthToken(response.accessToken);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
    } catch (e) {
      logger.e('Google Sign-In error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Login
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _authRepository.login(
        email: email,
        password: password,
      );

      // Set auth token in ApiClient for subsequent API calls
      _apiClient.setAuthToken(response.accessToken);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
    } catch (e) {
      logger.e('Login error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Register
  Future<void> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _authRepository.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );

      // Set auth token in ApiClient for subsequent API calls
      _apiClient.setAuthToken(response.accessToken);

      state = state.copyWith(
        status: AuthStatus.kycPending,
        user: response.user,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
    } catch (e) {
      logger.e('Register error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Submit KYC
  Future<void> submitKYC({
    required KYCSubmission submission,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.submitKYC(submission: submission);

      state = state.copyWith(
        status: AuthStatus.kycPending,
        user: state.user?.copyWith(kycStatus: 'pending'),
      );
    } catch (e) {
      logger.e('Submit KYC error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Check KYC status
  Future<void> checkKYCStatus() async {
    try {
      final status = await _authRepository.getKYCStatus();

      if (status == 'approved') {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: state.user?.copyWith(kycStatus: 'approved'),
        );
      } else if (status == 'rejected') {
        state = state.copyWith(
          status: AuthStatus.kycRejected,
          user: state.user?.copyWith(kycStatus: 'rejected'),
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.kycPending,
          user: state.user?.copyWith(kycStatus: 'pending'),
        );
      }
    } catch (e) {
      logger.e('Check KYC status error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Logout
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.logout();
      // Clear auth token
      _apiClient.clearAuthToken();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      logger.e('Logout error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Refresh token
  Future<void> refreshAccessToken() async {
    if (state.refreshToken == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final response = await _authRepository.refreshToken(state.refreshToken!);

      // Update auth token in ApiClient
      _apiClient.setAuthToken(response.accessToken);

      state = state.copyWith(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
    } catch (e) {
      logger.e('Refresh token error: $e');
      // Clear token and set unauthenticated on refresh failure
      _apiClient.clearAuthToken();
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  /// Get current user
  Future<void> getCurrentUser() async {
    try {
      final user = await _authRepository.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      logger.e('Get current user error: $e');
    }
  }

  /// Verify email
  Future<void> verifyEmail(String code) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.verifyEmail(code);
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      logger.e('Verify email error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Resend verification code
  Future<void> resendVerificationCode(String email) async {
    try {
      await _authRepository.resendVerificationCode(email);
    } catch (e) {
      logger.e('Resend verification error: $e');
      rethrow;
    }
  }

  /// Request password reset
  Future<void> requestPasswordReset(String email) async {
    try {
      await _authRepository.requestPasswordReset(email);
    } catch (e) {
      logger.e('Request password reset error: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword({
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.resetPassword(
        code: code,
        newPassword: newPassword,
      );
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (e) {
      logger.e('Reset password error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(status: AuthStatus.authenticated);
    } catch (e) {
      logger.e('Change password error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(authRepository, apiClient);
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});

/// Auth status provider
final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authProvider);
  return authState.status;
});

/// Is KYC pending provider
final isKycPendingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isKycPending;
});

/// Is KYC rejected provider
final isKycRejectedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isKycRejected;
});

/// Auth error provider
final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.error;
});
