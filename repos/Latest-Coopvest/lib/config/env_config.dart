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
        // Replit-hosted backend (works on physical devices and emulators)
        apiBaseUrl: 'https://4c670c48-4a19-4dab-ba0c-6e3e4151ea8e-00-17gtyzo9gaaeh.janeway.replit.dev/api/v1',
        appName: 'Coopvest Dev',
        enableLogging: true,
        useMockData: false,
      );

  static EnvConfig get staging => EnvConfig(
        // Replit-hosted backend — use this until production API is deployed
        apiBaseUrl: 'https://4c670c48-4a19-4dab-ba0c-6e3e4151ea8e-00-17gtyzo9gaaeh.janeway.replit.dev/api/v1',
        appName: 'Coopvest Staging',
        enableLogging: true,
      );

  static EnvConfig get prod => EnvConfig(
        apiBaseUrl: 'https://api.coopvest.africa/api/v1',
        appName: 'Coopvest Africa',
        enableLogging: false,
      );
}

class EnvironmentContext {
  static Environment _env = Environment.dev;
  static EnvConfig _config = EnvConfig.dev;

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
