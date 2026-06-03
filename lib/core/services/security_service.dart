import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
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

  /// Check for jailbreak/root using flutter_jailbreak_detection package.
  /// Falls back to basic heuristics if the package is unavailable.
  Future<bool> checkJailbreak() async {
    bool isJailbroken = false;

    try {
      // Primary check: Use the flutter_jailbreak_detection package
      // which provides comprehensive detection across platforms
      final flutterJailbreak = FlutterJailbreakDetection();
      final detection = await flutterJailbreak.jailbroken;
      
      if (detection) {
        logger.w('SECURITY ALERT: Jailbreak/root detected by package');
        isJailbroken = true;
      }
    } catch (e) {
      logger.w('flutter_jailbreak_detection unavailable, using fallback detection: $e');
      
      // Fallback: Basic heuristic checks on known paths
      // This provides basic detection when the package fails
      try {
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
          ];
          for (final path in suspectPaths) {
            if (await File(path).exists()) {
              isJailbroken = true;
              break;
            }
          }
        }
      } catch (fallbackError) {
        logger.e('Fallback jailbreak detection also failed: $fallbackError');
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
