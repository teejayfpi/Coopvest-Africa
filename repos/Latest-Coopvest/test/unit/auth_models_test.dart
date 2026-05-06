import 'package:flutter_test/flutter_test.dart';
import 'package:coopV/data/models/auth_models.dart';

void main() {
  group('User Model Tests', () {
    test('User fromJson creates valid user', () {
      final json = {
        'id': '123',
        'email': 'test@example.com',
        'firstName': 'John',
        'lastName': 'Doe',
        'phone': '+2341234567890',
        'isEmailVerified': true,
        'isKycVerified': false,
        'createdAt': '2024-01-01T00:00:00.000Z',
      };
      final user = User.fromJson(json);
      expect(user.id, '123');
      expect(user.email, 'test@example.com');
      expect(user.firstName, 'John');
    });

    test('User fullName returns combined name', () {
      final user = User(
        id: '123',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        phone: '+2341234567890',
        isEmailVerified: true,
        isKycVerified: false,
        createdAt: DateTime.now(),
      );
      expect(user.fullName, 'John Doe');
    });
  });
}
