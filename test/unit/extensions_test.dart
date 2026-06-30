import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/extensions/string_extensions.dart';
import 'package:coopvest_mobile/core/extensions/number_extensions.dart';

void main() {
  group('StringExtensions Tests', () {
    group('capitalize', () {
      test('should capitalize first letter of a word', () {
        expect('hello'.capitalize(), 'Hello');
        expect('world'.capitalize(), 'World');
      });

      test('should handle empty string', () {
        expect(''.capitalize(), '');
      });

      test('should handle already capitalized string', () {
        expect('Hello'.capitalize(), 'Hello');
      });

      test('should handle single character', () {
        expect('a'.capitalize(), 'A');
        expect('A'.capitalize(), 'A');
      });

      test('should handle multi-word string', () {
        expect('hello world'.capitalize(), 'Hello world');
      });
    });

    group('toTitleCase', () {
      test('should convert to title case', () {
        expect('hello world'.toTitleCase(), 'Hello World');
        expect('john doe'.toTitleCase(), 'John Doe');
      });

      test('should handle empty string', () {
        expect(''.toTitleCase(), '');
      });

      test('should handle already title case', () {
        expect('Hello World'.toTitleCase(), 'Hello World');
      });

      test('should handle multiple spaces', () {
        expect('hello   world'.toTitleCase(), 'Hello   World');
      });
    });

    group('removeWhitespace', () {
      test('should remove all whitespace', () {
        expect('hello world'.removeWhitespace(), 'helloworld');
        expect('  hello  '.removeWhitespace(), 'hello');
        expect('a b c d'.removeWhitespace(), 'abcd');
      });

      test('should handle empty string', () {
        expect(''.removeWhitespace(), '');
      });

      test('should handle tabs and newlines', () {
        expect('hello\tworld'.removeWhitespace(), 'helloworld');
        expect('hello\nworld'.removeWhitespace(), 'helloworld');
      });
    });

    group('isValidEmail', () {
      test('should return true for valid emails', () {
        expect('test@example.com'.isValidEmail(), isTrue);
        expect('user.name@domain.co.uk'.isValidEmail(), isTrue);
        expect('user+tag@example.org'.isValidEmail(), isTrue);
        expect('user123@test.io'.isValidEmail(), isTrue);
      });

      test('should return false for invalid emails', () {
        expect('invalid'.isValidEmail(), isFalse);
        expect('invalid@'.isValidEmail(), isFalse);
        expect('@domain.com'.isValidEmail(), isFalse);
        expect('user@'.isValidEmail(), isFalse);
        expect('user@domain'.isValidEmail(), isFalse);
        expect('user domain.com'.isValidEmail(), isFalse);
        expect(''.isValidEmail(), isFalse);
      });
    });

    group('isValidPhone', () {
      test('should return true for valid phone numbers', () {
        expect('08031234567'.isValidPhone(), isTrue);
        expect('2348012345678'.isValidPhone(), isTrue);
        expect('+2348012345678'.isValidPhone(), isTrue);
        expect('0803 123 4567'.isValidPhone(), isTrue);
      });

      test('should return false for invalid phone numbers', () {
        expect('123'.isValidPhone(), isFalse);
        expect('abcdefghij'.isValidPhone(), isFalse);
        expect(''.isValidPhone(), isFalse);
        expect('12345678901234'.isValidPhone(), isFalse); // too long
      });
    });
  });

  group('NumberExtensions Tests', () {
    group('formatNumber', () {
      test('should format numbers with thousand separators', () {
        expect(1000.formatNumber(), '1,000');
        expect(1000000.formatNumber(), '1,000,000');
        expect(123456789.formatNumber(), '123,456,789');
      });

      test('should handle zero', () {
        expect(0.formatNumber(), '0');
      });

      test('should handle small numbers', () {
        expect(100.formatNumber(), '100');
        expect(999.formatNumber(), '999');
      });

      test('should handle large numbers', () {
        expect(10000000000.formatNumber(), '10,000,000,000');
      });
    });

    group('formatCurrency', () {
      test('should format as Nigerian Naira', () {
        expect(1000.formatCurrency(), '₦1,000');
        expect(500000.formatCurrency(), '₦500,000');
        expect(1234567.formatCurrency(), '₦1,234,567');
      });

      test('should handle zero', () {
        expect(0.formatCurrency(), '₦0');
      });

      test('should handle decimals', () {
        expect(1234.56.formatCurrency(), '₦1,234'); // rounds to 0 decimals
      });
    });

    group('formatDecimal', () {
      test('should format with specified decimal places', () {
        expect(123.456.formatDecimal(2), '123.46');
        expect(100.0.formatDecimal(2), '100.00');
        expect(99.9.formatDecimal(1), '99.9');
      });

      test('should handle zero decimal places', () {
        expect(123.456.formatDecimal(0), '123');
        expect(100.0.formatDecimal(0), '100');
      });
    });

    group('toPercentage', () {
      test('should convert to percentage string', () {
        expect(0.5.toPercentage(), '50%');
        expect(0.1.toPercentage(), '10%');
        expect(1.0.toPercentage(), '100%');
      });

      test('should handle decimals parameter', () {
        expect(0.333.toPercentage(decimals: 1), '33.3%');
        expect(0.333.toPercentage(decimals: 2), '33.30%');
      });

      test('should handle zero', () {
        expect(0.toPercentage(), '0%');
      });
    });
  });
}
