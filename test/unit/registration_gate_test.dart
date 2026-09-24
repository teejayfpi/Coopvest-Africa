import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/auth_models.dart';

/// Regression tests for three reported bugs.
///
/// 1. A member who paid the registration fee was sent back to the payment
///    screen after closing and reopening the app. Root cause was the BACKEND:
///    `POST /auth/sync` omitted `registration_fee_paid` and `activation_gate`
///    from its response, so `User.fromJson` fell back to `false` and
///    `hasSettledRegistrationFee` was always false on a cold start. The model
///    tests below pin what the client must conclude from each payload shape.
///
/// 2. The activation screen showed "KYC ✅ Verified" for everyone, from a
///    hardcoded literal. The screen now derives it, so the status the model
///    reports is what matters — pinned here.
///
/// 3. A 401 whose body carries `code: SESSION_REPLACED` is not fixable by
///    refreshing a token (same session_id, still rejected), so the interceptor
///    must not retry it. Covered by the api_client test file.
void main() {
  group('registration-fee gate (bug 1)', () {
    test('a settled fee from the activation gate marks the member as paid', () {
      // This is the shape /auth/sync now returns.
      final u = User.fromJson({
        'id': 'p1',
        'email': 'a@b.c',
        'registration_fee_paid': true,
        'activation_gate': {
          'activated': true,
          'kyc_approved': true,
          'registration_fee_paid': true,
          'registration_fee_exempt': false,
          'registration_fee_settled': true,
          'blocked': false,
        },
      });
      expect(u.registrationFeePaid, isTrue);
      expect(u.registrationFeeSettled, isTrue);
      expect(u.hasSettledRegistrationFee, isTrue);
    });

    test('an UNPAID member is correctly gated', () {
      final u = User.fromJson({
        'id': 'p2',
        'email': 'a@b.c',
        'registration_fee_paid': false,
        'activation_gate': {
          'activated': false,
          'kyc_approved': true,
          'registration_fee_paid': false,
          'registration_fee_exempt': false,
          'registration_fee_settled': false,
          'blocked': false,
        },
      });
      expect(u.hasSettledRegistrationFee, isFalse);
    });

    test('a payroll-exempt member passes the gate without paying in-app', () {
      // Salary-deduction members have their fee recovered by their employer, so
      // sending them to the payment screen would demand money through a channel
      // that is not theirs.
      final u = User.fromJson({
        'id': 'p3',
        'email': 'a@b.c',
        'registration_fee_paid': false,
        'activation_gate': {
          'activated': true,
          'kyc_approved': true,
          'registration_fee_paid': false,
          'registration_fee_exempt': true,
          'registration_fee_settled': true,
          'blocked': false,
        },
      });
      expect(u.hasSettledRegistrationFee, isTrue,
          reason: 'the gate must be satisfied by the exemption, not by paying');
    });

    test('an older backend that only sends registration_fee_paid still works', () {
      final u = User.fromJson({
        'id': 'p4',
        'email': 'a@b.c',
        'registration_fee_paid': true,
      });
      expect(u.hasSettledRegistrationFee, isTrue);
    });

    test('a payload missing the fee fields entirely reads as unpaid', () {
      // The exact bug: /auth/sync used to send a payload with no fee fields, so
      // the client had to treat it as unpaid. This asserts the client-side
      // behaviour stays correct — the fix belongs on the server, and this is
      // the shape that must NOT be shipped again.
      final u = User.fromJson({
        'userId': 'USR-1',
        'id': 'p5',
        'email': 'a@b.c',
        'role': 'member',
        'kycStatus': 'approved',
        'membershipStatus': 'active',
      });
      expect(u.registrationFeePaid, isFalse);
      expect(u.hasSettledRegistrationFee, isFalse,
          reason: 'documents why omitting these fields starves the gate');
    });
  });

  group('KYC status (bug 2)', () {
    test('an approved member reports approved', () {
      final u = User.fromJson({
        'id': 'p1', 'email': 'a@b.c', 'kycVerified': true,
      });
      expect(u.kycStatus, 'approved');
    });

    test('a member awaiting review reports pending, NOT approved', () {
      // The screen used to print a hardcoded "Verified" here.
      final u = User.fromJson({
        'id': 'p2', 'email': 'a@b.c', 'kyc_verified': false,
        'kyc_status': 'pending',
      });
      expect(u.kycStatus, 'pending');
      expect(u.kycStatus == 'approved', isFalse,
          reason: 'the activation screen must not claim Verified while pending');
    });

    test('a rejected member reports rejected', () {
      final u = User.fromJson({
        'id': 'p3', 'email': 'a@b.c', 'kyc_status': 'rejected',
      });
      expect(u.kycStatus, 'rejected');
    });

    test('a missing kyc field defaults to pending, never approved', () {
      // Failing towards "approved" would show a false verification badge.
      final u = User.fromJson({'id': 'p4', 'email': 'a@b.c'});
      expect(u.kycStatus, 'pending');
    });
  });
}
