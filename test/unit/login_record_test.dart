import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/presentation/screens/security/login_history_screen.dart';

void main() {
  group('LoginRecord.fromJson', () {
    test('parses a full record from the backend payload', () {
      final record = LoginRecord.fromJson({
        'id': 'abc',
        'deviceName': 'iPhone 14 Pro',
        'deviceType': 'mobile',
        'location': 'Lagos, Nigeria',
        'ipAddress': '102.88.0.1',
        'date': '2024-01-15T10:30:00.000Z',
        'isSuccessful': true,
        'isCurrentSession': true,
      });

      expect(record.id, 'abc');
      expect(record.deviceName, 'iPhone 14 Pro');
      expect(record.deviceType, 'mobile');
      expect(record.location, 'Lagos, Nigeria');
      expect(record.ipAddress, '102.88.0.1');
      expect(record.date.toUtc(), DateTime.utc(2024, 1, 15, 10, 30));
      expect(record.isSuccessful, isTrue);
      expect(record.isCurrentSession, isTrue);
    });

    test('falls back to a placeholder device name when missing', () {
      final record = LoginRecord.fromJson({'id': 'x'});

      expect(record.deviceName, 'Unknown device');
      expect(record.deviceType, 'unknown');
      expect(record.location, '');
      expect(record.ipAddress, '');
      expect(record.isSuccessful, isFalse);
      expect(record.isCurrentSession, isFalse);
    });

    test('does not throw on an unparseable date', () {
      final record = LoginRecord.fromJson({'id': 'x', 'date': 'not-a-date'});
      expect(record.date, isA<DateTime>());
    });
  });
}
