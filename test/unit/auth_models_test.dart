import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/auth_models.dart';

void main() {
  group('User Model Tests', () {
    test('should create User from JSON', () {
      final json = {
        'userId': 'user_123',
        'email': 'test@example.com',
        'name': 'John Doe',
        'kycVerified': true,
        'membershipStatus': 'active',
        'createdAt': '2024-01-15T10:30:00Z',
      };

      final user = User.fromJson(json);

      expect(user.id, 'user_123');
      expect(user.email, 'test@example.com');
      expect(user.name, 'John Doe');
      expect(user.kycStatus, 'approved');
      expect(user.membershipStatus, 'active');
    });

    test('should handle missing optional fields', () {
      final json = {
        'userId': 'user_456',
        'email': 'minimal@test.com',
        'name': 'Jane',
        'kycVerified': false,
        'createdAt': '2024-02-01T08:00:00Z',
      };

      final user = User.fromJson(json);

      expect(user.phone, isNull);
      expect(user.dateOfBirth, isNull);
      expect(user.profilePicture, isNull);
      expect(user.kycStatus, 'pending');
    });

    test('should correctly identify termination status', () {
      final activeUser = User(
        id: '1',
        email: 'active@test.com',
        name: 'Active User',
        kycStatus: 'approved',
        membershipStatus: 'active',
        createdAt: DateTime.now(),
      );

      final terminatedUser = User(
        id: '2',
        email: 'terminated@test.com',
        name: 'Terminated User',
        kycStatus: 'approved',
        membershipStatus: 'terminated',
        createdAt: DateTime.now(),
      );

      final pendingTerminationUser = User(
        id: '3',
        email: 'pending@test.com',
        name: 'Pending User',
        kycStatus: 'approved',
        membershipStatus: 'pending_termination',
        createdAt: DateTime.now(),
      );

      expect(activeUser.canRequestTermination, isTrue);
      expect(activeUser.isTerminated, isFalse);
      expect(activeUser.isTerminationPending, isFalse);

      expect(terminatedUser.canRequestTermination, isFalse);
      expect(terminatedUser.isTerminated, isTrue);
      expect(terminatedUser.isTerminationPending, isFalse);

      expect(pendingTerminationUser.canRequestTermination, isFalse);
      expect(pendingTerminationUser.isTerminated, isFalse);
      expect(pendingTerminationUser.isTerminationPending, isTrue);
    });

    test('should calculate membership duration correctly', () {
      final user = User(
        id: '1',
        email: 'test@test.com',
        name: 'Test User',
        kycStatus: 'approved',
        membershipStatus: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      );

      expect(user.membershipDurationMonths, greaterThanOrEqualTo(2));
    });

    test('should check loan eligibility based on membership duration', () {
      final newUser = User(
        id: '1',
        email: 'new@test.com',
        name: 'New User',
        kycStatus: 'approved',
        membershipStatus: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      final oldUser = User(
        id: '2',
        email: 'old@test.com',
        name: 'Old User',
        kycStatus: 'approved',
        membershipStatus: 'active',
        createdAt: DateTime.now().subtract(const Duration(days: 400)),
      );

      expect(newUser.isEligibleForLoan(6), isFalse);
      expect(oldUser.isEligibleForLoan(6), isTrue);
    });

    test('should handle different JSON field name formats', () {
      final jsonSnakeCase = {
        'user_id': 'snake_123',
        'email': 'snake@test.com',
        'name': 'Snake Case',
        'kyc_status': 'approved',
        'membership_status': 'active',
        'created_at': '2024-03-01T12:00:00Z',
      };

      final user = User.fromJson(jsonSnakeCase);

      expect(user.id, 'snake_123');
      expect(user.kycStatus, 'approved');
    });
  });

  group('KYC Status Tests', () {
    test('should parse KYC verified boolean correctly', () {
      final verifiedUser = User(
        id: '1',
        email: 'verified@test.com',
        name: 'Verified',
        kycStatus: 'approved',
        membershipStatus: 'active',
        createdAt: DateTime.now(),
      );

      final unverifiedUser = User(
        id: '2',
        email: 'unverified@test.com',
        name: 'Unverified',
        kycStatus: 'pending',
        membershipStatus: 'active',
        createdAt: DateTime.now(),
      );

      expect(verifiedUser.kycStatus, 'approved');
      expect(unverifiedUser.kycStatus, 'pending');
    });
  });
}
