import 'package:flutter_test/flutter_test.dart';
import 'package:coopV/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('App name is correct', () {
      expect(AppConfig.appName, 'Coopvest Africa');
    });

    test('API base URL is set', () {
      expect(AppConfig.apiBaseUrl, isNotEmpty);
      expect(AppConfig.apiBaseUrl.startsWith('http'), true);
    });
  });
}
