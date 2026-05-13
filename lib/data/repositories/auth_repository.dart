import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
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

/// Auth Repository — Firebase Auth + backend profile sync
///
/// Authentication flow:
///   1. Sign in/up directly with Firebase Auth SDK (no backend call needed)
///   2. Get the Firebase ID token
///   3. Send the ID token to the backend to sync/create the profile row
///   4. Backend returns the full User payload
class AuthRepository {
  final ApiClient _apiClient;
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _cachedUser;

  AuthRepository(this._apiClient);

  // ─── helpers ────────────────────────────────────────────────────────────────

  /// Get a fresh Firebase ID token and attach it to the API client.
  Future<String> _refreshAndAttachToken() async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) throw AuthException('No authenticated Firebase user');
    final token = await fbUser.getIdToken(true);
    if (token == null) throw AuthException('Failed to get Firebase ID token');
    _apiClient.setAuthToken(token);
    await TokenStorage.saveTokens(accessToken: token);
    logger.i('Auth token refreshed and saved to secure storage');
    return token;
  }

  /// Check if there's a valid Firebase session (for biometric login)
  Future<bool> hasValidSession() async {
    return _firebaseAuth.currentUser != null;
  }

  /// Get the current Firebase user (for biometric login without re-auth)
  fb.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Sync profile with backend after any Firebase sign-in and return User.
  /// If backend sync fails (404/400), create a local User from Firebase data.
  Future<User> _syncWithBackend() async {
    await _refreshAndAttachToken();
    
    try {
      final response = await _apiClient.post('/auth/sync');
      final user = User.fromJson(response['user'] as Map<String, dynamic>);
      _cachedUser = user;
      return user;
    } catch (e) {
      // If sync endpoint fails (404 Resource not found, 400 Bad request),
      // create a User from Firebase data so login can proceed
      logger.w('Backend sync failed: $e - using Firebase user data');
      
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser == null) throw AuthException('No authenticated user');
      
      // Try to get user from /auth/me endpoint as fallback
      try {
        final meResponse = await _apiClient.get('/auth/me');
        if (meResponse is Map<String, dynamic>) {
          final userData = meResponse.containsKey('user') 
              ? meResponse['user'] as Map<String, dynamic>
              : meResponse;
          final user = User.fromJson(userData);
          _cachedUser = user;
          return user;
        }
      } catch (meError) {
        logger.w('Backend /auth/me also failed: $meError');
      }
      
      // Create minimal User from Firebase data as last resort
      final user = User(
        id: fbUser.uid,
        name: fbUser.displayName ?? 'User',
        email: fbUser.email ?? '',
        phone: fbUser.phoneNumber,
        isEmailVerified: fbUser.emailVerified,
        kycStatus: 'pending',
        createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
      );
      _cachedUser = user;
      return user;
    }
  }

  // ─── Sign-in methods ─────────────────────────────────────────────────────────

  /// Email + password login
  Future<User> login({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return await _syncWithBackend();
    } on fb.FirebaseAuthException catch (e) {
      logger.e('Firebase login error: ${e.code}');
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      logger.e('Login error: $e');
      rethrow;
    }
  }

  /// Register with email + password
  Future<User> register({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? deviceId,
    String? referralCode,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name in Firebase
      await credential.user?.updateDisplayName(name);

      // Send email verification
      try {
        await credential.user?.sendEmailVerification();
        logger.i('Verification email sent successfully to ${email.trim()}');
      } catch (emailError) {
        logger.e('Failed to send verification email: $emailError');
        // Continue with registration even if email fails
      }

      // Attach token and create backend profile
      await _refreshAndAttachToken();
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'name': name,
          'phone': phone,
          'referralCode': referralCode,
        },
      );

      final user = User.fromJson(response['user'] as Map<String, dynamic>);
      _cachedUser = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      logger.e('Firebase register error: ${e.code}');
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      logger.e('Register error: $e');
      rethrow;
    }
  }

  /// Google Sign-In
  Future<User> googleSignIn({String? deviceId}) async {
    try {
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) throw AuthException('Google sign-in cancelled');

      final googleAuth = await googleAccount.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      return await _syncWithBackend();
    } on fb.FirebaseAuthException catch (e) {
      logger.e('Firebase Google sign-in error: ${e.code}');
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      logger.e('Google sign-in error: $e');
      rethrow;
    }
  }

  /// Register FCM token with the backend
  Future<void> registerFcmToken(String fcmToken) async {
    try {
      await _apiClient.post('/notifications/fcm-token', data: {'token': fcmToken});
      logger.i('FCM token registered with backend');
    } catch (e) {
      logger.w('FCM token registration failed (non-fatal): $e');
    }
  }

  /// Submit KYC
  Future<void> submitKYC({required KYCSubmission submission}) async {
    try {
      await _apiClient.post('/auth/kyc/submit', data: submission.toJson());
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

  /// Logout — signs out from Firebase and revokes backend tokens
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (e) {
      logger.w('Backend logout error (non-fatal): $e');
    } finally {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      _apiClient.clearAuthToken();
      await TokenStorage.clearTokens();
      _cachedUser = null;
    }
  }

  /// Get current user (with caching)
  /// Falls back to Firebase user data if backend is unavailable
  Future<User> getCurrentUser({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUser != null) return _cachedUser!;
    
    try {
      final response = await _apiClient.get('/auth/me');
      if (response is Map<String, dynamic> && response.containsKey('user')) {
        _cachedUser = User.fromJson(response['user'] as Map<String, dynamic>);
      } else {
        _cachedUser = User.fromJson(response as Map<String, dynamic>);
      }
      return _cachedUser!;
    } catch (e) {
      logger.w('Get current user from backend failed: $e');
      
      // Fallback to Firebase user if backend fails
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser != null) {
        _cachedUser = User(
          id: fbUser.uid,
          name: fbUser.displayName ?? 'User',
          email: fbUser.email ?? '',
          phone: fbUser.phoneNumber,
          isEmailVerified: fbUser.emailVerified,
          kycStatus: 'pending',
          createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
        );
        return _cachedUser!;
      }
      rethrow;
    }
  }

  /// Password reset — sends Firebase reset email (no backend call needed)
  Future<void> requestPasswordReset(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      // Always return success to prevent email enumeration
      logger.w('Password reset email error (non-fatal): ${e.code}');
    } catch (e) {
      logger.e('Request password reset error: $e');
      rethrow;
    }
  }

  /// Reset password with OTP code — Firebase handles via the deep-link/OTP flow
  Future<void> resetPassword({required String code, required String newPassword}) async {
    try {
      await _firebaseAuth.confirmPasswordReset(code: code, newPassword: newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  /// Change password — re-authenticates then updates in Firebase
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser == null || fbUser.email == null) throw AuthException('Not authenticated');

      // Re-authenticate
      final credential = fb.EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);
      await fbUser.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  /// Email verification — sends verification email
  Future<void> verifyEmail(String code) async {
    try {
      await _firebaseAuth.currentUser?.sendEmailVerification();
    } catch (e) {
      logger.e('Verify email error: $e');
      rethrow;
    }
  }

  /// Resend email verification
  Future<void> resendVerificationCode(String email) async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        throw AuthException('No user signed in. Please sign in again.');
      }
      await currentUser.sendEmailVerification();
      logger.i('Verification email resent successfully to ${currentUser.email}');
    } on fb.FirebaseAuthException catch (e) {
      logger.e('Resend verification Firebase error: ${e.code} - ${e.message}');
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      logger.e('Resend verification error: $e');
      rethrow;
    }
  }

  /// Restore session on app startup using Firebase's persisted auth state
  /// This ensures users stay logged in until they explicitly sign out
  Future<bool> restoreSession() async {
    try {
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser == null) {
        logger.i('No Firebase user found - session not restored');
        return false;
      }

      logger.i('Firebase user found: ${fbUser.email} - restoring session...');

      // Refresh token and re-attach to API client
      await _refreshAndAttachToken();
      
      // Try to get user from backend, but don't fail if backend is down
      try {
        await getCurrentUser(forceRefresh: true);
        logger.i('Session restored successfully from backend');
      } catch (e) {
        logger.w('Backend user fetch failed during restore, using Firebase data: $e');
        // getCurrentUser already handles fallback to Firebase user
      }
      
      return true;
    } catch (e) {
      logger.e('Session restore failed: $e');
      // Only clear tokens if Firebase auth itself failed, not just backend
      if (_firebaseAuth.currentUser == null) {
        _apiClient.clearAuthToken();
        await TokenStorage.clearTokens();
      }
      return false;
    }
  }

  /// Restore session for biometric login - refreshes token without full re-auth
  Future<User> restoreSessionWithBiometric() async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) throw AuthException('No authenticated session found');
    
    // Refresh token and return user
    await _refreshAndAttachToken();
    return await getCurrentUser(forceRefresh: true);
  }

  // Legacy token refresh — kept for backward-compat with ErrorInterceptor
  Future<AuthResponse> refreshToken(String refreshToken) async {
    try {
      final token = await _refreshAndAttachToken();
      final user = await getCurrentUser(forceRefresh: true);
      return AuthResponse(
        accessToken: token,
        refreshToken: '',
        user: user,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    } catch (e) {
      logger.e('Token refresh error: $e');
      rethrow;
    }
  }

  Future<String> getUserId() async => (await getCurrentUser()).id;
  Future<String> getUserName() async => (await getCurrentUser()).name;
  Future<String?> getUserPhone() async => (await getCurrentUser()).phone;

  // ─── Error mapping ────────────────────────────────────────────────────────

  String _mapFirebaseError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'requires-recent-login':
        return 'Please log in again before making this change.';
      case 'expired-action-code':
        return 'This link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'Invalid reset code. Please request a new one.';
      case 'channel-error':
        // This handles the PigeonUserDetails error in older versions
        return 'Authentication service error. Please update the app.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
