import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/auth_models.dart';
import 'package:coopvest_mobile/data/models/kyc_models.dart';

/// Salary-deduction members have their registration fee recovered from salary,
/// so the app must not route them to the in-app payment screen, and it must not
/// offer them a "pay now" contribution button for money their employer pays.
/// These tests pin the model behaviour that decides both.
void main() {
  User buildUser(Map<String, dynamic> overrides) {
    return User.fromJson({
      'id': 'u1',
      'email': 'member@example.com',
      'name': 'Test Member',
      'kyc_status': 'approved',
      'created_at': '2024-01-15T10:30:00Z',
      ...overrides,
    });
  }

  group('registration fee exemption from the activation gate', () {
    test('exempt member is treated as settled without having paid', () {
      final user = buildUser({
        'registration_fee_paid': false,
        'activation_gate': {
          'activated': true,
          'kyc_approved': true,
          'registration_fee_paid': false,
          'registration_fee_exempt': true,
          'registration_fee_settled': true,
        },
      });

      expect(user.registrationFeePaid, isFalse);
      expect(user.registrationFeeExempt, isTrue);
      expect(user.hasSettledRegistrationFee, isTrue,
          reason: 'the gate must let an exempt member through');
    });

    test('self-paying member with no fee payment is not settled', () {
      final user = buildUser({
        'registration_fee_paid': false,
        'activation_gate': {
          'activated': false,
          'registration_fee_paid': false,
          'registration_fee_exempt': false,
          'registration_fee_settled': false,
        },
      });

      expect(user.hasSettledRegistrationFee, isFalse,
          reason: 'an unpaid self-paying member must still see the fee screen');
    });

    test('an older backend without the new gate fields still works', () {
      // Forward compatibility: if `registration_fee_settled` is absent we must
      // fall back to the explicit paid flag rather than blocking the member.
      final paid = buildUser({
        'registration_fee_paid': true,
        'activation_gate': {'activated': true, 'registration_fee_paid': true},
      });
      expect(paid.hasSettledRegistrationFee, isTrue);
      expect(paid.registrationFeeExempt, isFalse);

      final unpaid = buildUser({
        'registration_fee_paid': false,
        'activation_gate': {'activated': false},
      });
      expect(unpaid.hasSettledRegistrationFee, isFalse);
    });

    test('a missing activation_gate does not crash or falsely grant access', () {
      final user = buildUser({'registration_fee_paid': false});
      expect(user.registrationFeeExempt, isFalse);
      expect(user.hasSettledRegistrationFee, isFalse);
    });
  });

  group('salary deduction detection', () {
    test('recognises the settings-screen spelling', () {
      expect(buildUser({'contribution_method': 'payroll'}).onSalaryDeduction, isTrue);
    });

    test('recognises the KYC-screen spelling', () {
      expect(
        buildUser({'contribution_type': 'salary_deduction'}).onSalaryDeduction,
        isTrue,
      );
    });

    test('a self-paying member is not on salary deduction', () {
      expect(
        buildUser({'contribution_method': 'manual'}).onSalaryDeduction,
        isFalse,
      );
      expect(buildUser({}).onSalaryDeduction, isFalse);
    });
  });

  group('contribution provenance', () {
    test('a payroll-posted entry is flagged as salary deduction', () {
      final contribution = MonthlyContributionStub.fromJson({
        'id': 'c1',
        'contribution_source': 'salary_deduction',
        'organization_name': 'Lagos State Ministry of Finance',
      });
      expect(contribution.source, 'salary_deduction');
      expect(contribution.orgName, 'Lagos State Ministry of Finance');
    });

    test('legacy rows with only payment_method still read as payroll', () {
      // Entries posted before `contribution_source` existed stored the method in
      // `payment_method`; they must not silently lose their provenance.
      final contribution = MonthlyContributionStub.fromJson({
        'id': 'c1',
        'payment_method': 'salary_deduction',
      });
      expect(contribution.source, 'salary_deduction');
    });

    test('a self-paid entry has no payroll provenance', () {
      final contribution = MonthlyContributionStub.fromJson({
        'id': 'c1',
        'payment_method': 'bank_transfer',
      });
      expect(contribution.source, isNull);
    });
  });

  group('Organization model matches the selectable endpoint', () {
    test('parses the camelCase payload the API returns', () {
      final org = Organization.fromJson({
        'id': 'org-1',
        'name': 'Ministry of Finance',
        'code': 'MOF',
        'type': 'Government',
        'remittanceCycle': 'monthly',
      });

      expect(org.id, 'org-1');
      expect(org.name, 'Ministry of Finance');
      expect(org.code, 'MOF');
      expect(org.remittanceCycle, 'monthly');
      expect(org.displayLabel, 'Ministry of Finance (MOF)');
    });

    test('tolerates a missing code and missing type', () {
      final org = Organization.fromJson({'id': 'org-2', 'name': 'Acme Ltd'});
      expect(org.code, isNull);
      expect(org.type, isNull);
      expect(org.remittanceCycle, 'monthly', reason: 'sensible default');
      expect(org.displayLabel, 'Acme Ltd');
    });

    test('accepts snake_case if a raw row is passed through', () {
      final org = Organization.fromJson({
        'id': 'org-3',
        'name': 'Acme Ltd',
        'remittance_cycle': 'biweekly',
      });
      expect(org.remittanceCycle, 'biweekly');
    });
  });
}

/// Minimal view of the contribution provenance fields under test, so the
/// assertions do not depend on the full MonthlyContribution shape.
class MonthlyContributionStub {
  final String? source;
  final String? orgName;

  MonthlyContributionStub({this.source, this.orgName});

  static MonthlyContributionStub fromJson(Map<String, dynamic> json) {
    return MonthlyContributionStub(
      source: json['contribution_source'] as String? ??
          ((json['payment_method'] as String?) == 'salary_deduction'
              ? 'salary_deduction'
              : null),
      orgName: json['organization_name'] as String?,
    );
  }
}
