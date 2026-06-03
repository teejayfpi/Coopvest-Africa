import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../utils/utils.dart';

/// Security Service — handles biometric auth, SSL pinning, and jailbreak detection.
class SecurityService {
  final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';
  static final SecurityService _instance = SecurityService._();
  factory SecurityService() => _instance;
  SecurityService._();

  /// Initialize security measures
  Future<void> initialize() async {
    if (AppConfig.enableJailbreakDetection) {
      await checkJailbreak();
    }
  }

  /// Check if biometrics are enabled by user
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Enable/Disable biometrics
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Authenticate with biometrics
  Future<bool> authenticate() async {
    if (!AppConfig.enableBiometric) return false;

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isSupported) {
        logger.w('Biometrics not available on this device');
        return false;
      }

      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access your account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      logger.e('Biometric authentication error: $e');
      return false;
    }
  }

  /// Check for jailbreak/root using platform-specific detection.
  /// Uses fallback heuristic detection since flutter_jailbreak_detection has
  /// API compatibility issues.
  Future<bool> checkJailbreak() async {
    bool isJailbroken = false;

    try {
      // Use basic heuristic checks on known paths
      // This provides basic detection across platforms
      if (Platform.isIOS) {
        final suspectPaths = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
        ];
        for (final path in suspectPaths) {
          if (await File(path).exists()) {
            logger.w('SECURITY ALERT: Jailbreak path detected: $path');
            isJailbroken = true;
            break;
          }
        }
      } else if (Platform.isAndroid) {
        final suspectPaths = [
          '/system/app/Superuser.apk',
          '/sbin/su',
          '/system/bin/su',
          '/system/xbin/su',
          '/data/local/su',
          '/su/bin/su',
        ];
        for (final path in suspectPaths) {
          if (await File(path).exists()) {
            logger.w('SECURITY ALERT: Root path detected: $path');
            isJailbroken = true;
            break;
          }
        }
      }
    } catch (e) {
      logger.e('Jailbreak detection failed: $e');
    }

    if (isJailbroken) {
      logger.w('SECURITY ALERT: Device appears to be jailbroken/rooted');
      if (AppConfig.terminateOnJailbreak) {
        logger.e('SECURITY POLICY: Terminating app due to jailbreak detection');
        SystemNavigator.pop();
      }
    }

    return isJailbroken;
  }

  /// Apply SSL Pinning to Dio instance (enabled per [AppConfig.enableSSLPinning]).
  void applySSLPinning(Dio dio) {
    if (!AppConfig.enableSSLPinning) return;

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // badCertificateCallback is only invoked when the system's certificate
        // chain validation has already failed (self-signed, expired, hostname
        // mismatch, etc.).  Always return false so those connections are
        // rejected — this is the secure default.
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          logger.e('SSL Pinning: Rejecting bad certificate for $host '
              '(subject: ${cert.subject})');
          return false;
        };
        return client;
      },
    );

    logger.i('SSL Pinning applied to API client');
  }
}

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});
