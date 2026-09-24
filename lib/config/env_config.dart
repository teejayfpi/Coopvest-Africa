import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

enum Environment { dev, staging, prod }

class EnvConfig {
  final String apiBaseUrl;
  final String appName;
  final bool enableLogging;
  final bool useMockData;

  EnvConfig({
    required this.apiBaseUrl,
    required this.appName,
    this.enableLogging = true,
    this.useMockData = false,
  });

  static EnvConfig get dev => EnvConfig(
        // Development: local backend reached from the device/emulator.
        //
        // `10.0.2.2` is the Android emulator's alias for the host machine. It
        // does NOT exist on iOS — the iOS Simulator shares the host's network
        // stack, so it must use `localhost`. Hardcoding the Android alias meant
        // `flutter run --dart-define=ENV=dev` on an iPhone or the iOS Simulator
        // could never reach a local backend.
        //
        // A physical iPhone can reach neither: it needs the host's LAN address.
        // Override with API_BASE_URL when running on real hardware.
        apiBaseUrl: devApiBaseUrl,
        appName: 'Coopvest Dev',
        enableLogging: true,
        useMockData: false,
      );

  /// Host address for a locally-run backend, resolved per platform.
  ///
  /// Reads `API_BASE_URL` first so a physical device (which resolves neither
  /// `10.0.2.2` nor `localhost` to your machine) can be pointed at the host's
  /// LAN IP without editing this file.
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE_URL');

  static String get devApiBaseUrl {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    if (kIsWeb) return 'http://localhost:5000/api/v1';
    // DefaultTargetPlatform is safe here: on the iOS Simulator this evaluates to
    // iOS and localhost reaches the host machine.
    return defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? 'http://localhost:5000/api/v1'
        : 'http://10.0.2.2:5000/api/v1';
  }

  static EnvConfig get staging => EnvConfig(
        // Staging: Coopvest backend on Render
        apiBaseUrl: 'https://coopvest-api.onrender.com/api',
        appName: 'Coopvest Staging',
        enableLogging: true,
      );

  static EnvConfig get prod => EnvConfig(
        // Production: Coopvest backend on Render
        apiBaseUrl: 'https://coopvest-api.onrender.com/api',
        appName: 'Coopvest Africa',
        enableLogging: false,
      );
}

class EnvironmentContext {
  static Environment _env = Environment.staging; // Default to staging for mobile builds
  static EnvConfig _config = EnvConfig.staging;

  static void setEnvironment(Environment env) {
    _env = env;
    switch (env) {
      case Environment.dev:
        _config = EnvConfig.dev;
        break;
      case Environment.staging:
        _config = EnvConfig.staging;
        break;
      case Environment.prod:
        _config = EnvConfig.prod;
        break;
    }
  }

  static Environment get env => _env;
  static EnvConfig get config => _config;
}
