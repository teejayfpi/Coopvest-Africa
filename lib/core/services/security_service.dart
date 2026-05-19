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

  /// Check for jailbreak/root.
  ///
  /// In production, integrate `flutter_jailbreak_detection` for real detection.
  /// Until then, we perform basic heuristic checks on known paths.
  Future<bool> checkJailbreak() async {
    bool isJailbroken = false;

    try {
      if (Platform.isIOS) {
        // Heuristic: check for common jailbreak artefacts
        final suspectPaths = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/usr/sbin/sshd',
          '/etc/apt',
          '/private/var/lib/apt/',
        ];
        for (final path in suspectPaths) {
          if (await File(path).exists()) {
            isJailbroken = true;
            break;
          }
        }
      } else if (Platform.isAndroid) {
        // Heuristic: check for su binary and known root management apps
        final suspectPaths = [
          '/system/app/Superuser.apk',
          '/sbin/su',
          '/system/bin/su',
          '/system/xbin/su',
          '/data/local/xbin/su',
          '/data/local/bin/su',
          '/system/sd/xbin/su',
          '/system/bin/failsafe/su',
          '/data/local/su',
        ];
        for (final path in suspectPaths) {
          if (await File(path).exists()) {
            isJailbroken = true;
            break;
          }
        }
      }

      if (isJailbroken) {
        logger.w('SECURITY ALERT: Device appears to be jailbroken/rooted');
        if (AppConfig.terminateOnJailbreak) {
          logger.e('SECURITY POLICY: Terminating app due to jailbreak detection');
          // Dismiss gracefully — on a truly compromised device the user can
          // reopen the app, but server-side device blacklisting is the
          // authoritative enforcement mechanism.
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      logger.e('Error during jailbreak detection: $e');
    }

    return isJailbroken;
  }

  /// Apply SSL Pinning to Dio instance (enabled per [AppConfig.enableSSLPinning]).
  void applySSLPinning(Dio dio) {
    if (!AppConfig.enableSSLPinning) return;

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          // When a fingerprint is configured, verify it matches.
          if (AppConfig.sslFingerprint.isNotEmpty) {
            final thumbprint = cert.sha256
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(':')
                .toUpperCase();
            final match = thumbprint == AppConfig.sslFingerprint.toUpperCase();
            if (!match) {
              logger.e(
                  'SSL Pinning: Certificate mismatch for $host. Rejecting.');
            }
            return match;
          }
          // No fingerprint configured — reject all bad certs in prod.
          logger.w('SSL Pinning: No fingerprint set; blocking bad cert for $host');
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
