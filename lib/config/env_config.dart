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
        // Development: Replit dev server
        // Local Android emulator: use http://10.0.2.2:5000/api/v1
        // Local iOS simulator:    use http://localhost:5000/api/v1
        apiBaseUrl: 'https://539e7840-36be-484d-bc70-5c1dfb597b95-00-35k57ivrof48y.picard.replit.dev/api/v1',
        appName: 'Coopvest Dev',
        enableLogging: true,
        useMockData: false,
      );

  static EnvConfig get staging => EnvConfig(
        // Staging: Render deployment
        apiBaseUrl: 'https://coopvest-api.onrender.com/api/v1',
        appName: 'Coopvest Staging',
        enableLogging: true,
      );

  static EnvConfig get prod => EnvConfig(
        // Production: Render deployment
        apiBaseUrl: 'https://coopvest-api.onrender.com/api/v1',
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
