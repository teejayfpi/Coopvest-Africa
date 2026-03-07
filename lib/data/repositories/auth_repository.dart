import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';
import '../models/auth_models.dart';
import '../models/kyc_models.dart';

/// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

/// Auth Repository
class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  /// Login with email and password
  /// Login with Google
  Future<AuthResponse> googleSignIn({
    required String idToken,
    String? deviceId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/google',
        data: {
          'idToken': idToken,
          'deviceId': deviceId,
        },
      );

      return AuthResponse.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Google Sign-In error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    try {
      final request = LoginRequest(
        email: email,
        password: password,
        deviceId: deviceId,
      );

      final response = await _apiClient.post(
        '/auth/login',
        data: request.toJson(),
      );

      return AuthResponse.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Login error: $e');
      rethrow;
    }
  }

  /// Register new user
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? deviceId,
    String? referralCode,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'phone': phone,
          'deviceId': deviceId,
          'referralCode': referralCode,
        },
      );

      return AuthResponse.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Register error: $e');
      rethrow;
    }
  }

  /// Submit KYC
  Future<void> submitKYC({
    required KYCSubmission submission,
  }) async {
    try {
      await _apiClient.post(
        '/auth/kyc/submit',
        data: submission.toJson(),
      );
    } catch (e) {
      logger.e('KYC submission error: $e');
      rethrow;
    }
  }

  /// Get KYC status
  Future<String> getKYCStatus() async {
    try {
      final response = await _apiClient.get('/auth/kyc/status');
      return response['status'] as String;
    } catch (e) {
      logger.e('Get KYC status error: $e');
      rethrow;
    }
  }

  /// Refresh token
  Future<AuthResponse> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      return AuthResponse.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Refresh token error: $e');
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
      _apiClient.clearAuthToken();
    } catch (e) {
      logger.e('Logout error: $e');
      // Clear token even if logout fails
      _apiClient.clearAuthToken();
    }
  }

  /// Get current user
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/me');
      // The backend returns { success: true, user: { ... } }
      if (response is Map<String, dynamic> && response.containsKey('user')) {
        return User.fromJson(response['user'] as Map<String, dynamic>);
      }
      return User.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Get current user error: $e');
      rethrow;
    }
  }

  /// Verify email
  Future<void> verifyEmail(String code) async {
    try {
      await _apiClient.post(
        '/auth/verify-email',
        data: {'code': code},
      );
    } catch (e) {
      logger.e('Verify email error: $e');
      rethrow;
    }
  }

  /// Resend verification code
  Future<void> resendVerificationCode(String email) async {
    try {
      await _apiClient.post(
        '/auth/resend-verification',
        data: {'email': email},
      );
    } catch (e) {
      logger.e('Resend verification error: $e');
      rethrow;
    }
  }

  /// Request password reset
  Future<void> requestPasswordReset(String email) async {
    try {
      await _apiClient.post(
        '/auth/request-password-reset',
        data: {'email': email},
      );
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
    try {
      await _apiClient.post(
        '/auth/reset-password',
        data: {
          'code': code,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      logger.e('Reset password error: $e');
      rethrow;
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      logger.e('Change password error: $e');
      rethrow;
    }
  }
  Future<String> getUserId() async {
    final user = await getCurrentUser();
    return user.id;
  }

  Future<String> getUserName() async {
    final user = await getCurrentUser();
    return user.name;
  }

  Future<String?> getUserPhone() async {
    final user = await getCurrentUser();
    return user.phone;
  }
}
