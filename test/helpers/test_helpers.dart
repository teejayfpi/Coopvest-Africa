import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mock provider container for testing
class TestProviderScope {
  /// `overrides` is a `List<Override>` — that is the type Riverpod actually
  /// accepts. It was previously declared as `Map<Provider, ProviderOverride>`,
  /// which is neither: `ProviderOverride` is not a Riverpod type (the type is
  /// `Override`), and a Map is not assignable to the `List<Override>` both
  /// `ProviderContainer` and `ProviderScope` require. That made this helper
  /// fail to compile, so any test importing it could not run.
  static ProviderContainer create({
    List<Override>? overrides,
  }) {
    return ProviderContainer(overrides: overrides ?? const []);
  }

  static Widget wrapWithProvider({
    required Widget child,
    List<Override>? overrides,
  }) {
    return ProviderScope(
      overrides: overrides ?? const [],
      child: child,
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
