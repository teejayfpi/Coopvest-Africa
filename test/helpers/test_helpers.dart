import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mock provider container for testing
class TestProviderScope {
  static ProviderContainer create({
    Map<Provider, ProviderOverride>? overrides,
  }) {
    return ProviderContainer(overrides: overrides ?? {});
  }

  static Widget wrapWithProvider({
    required Widget child,
    Map<Provider, ProviderOverride>? overrides,
  }) {
    return ProviderScope(
      child: child,
      overrides: overrides ?? {},
    );
  }
}

/// Common test utilities
class TestUtils {
  /// Generate a random email for testing
  static String generateTestEmail() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'test_$timestamp@example.com';
  }

  /// Generate a random phone number
  static String generateTestPhone() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '+234$timestamp'.substring(0, 14);
  }
}

/// Mock SharedPreferences for testing
class MockSharedPreferences {
  static Future<dynamic> getMock() async {
    return {};
  }
}
