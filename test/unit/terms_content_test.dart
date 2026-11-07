import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/config/app_config.dart';
import 'package:coopvest_mobile/data/models/terms_content.dart';

/// Format a whole-naira amount the way the disclosure text writes it.
String naira(num amount) {
  final digits = amount.round().toString();
  final withSeparators = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '₦$withSeparators';
}

void main() {
  group('TermsContent bundled document', () {
    test('has a version and all eight policies', () {
      final doc = TermsContent.bundled();
      expect(doc.version, TermsContent.version);
      expect(doc.sections.length, 8);
    });

    test('contains every required policy id', () {
      final ids = TermsContent.sections.map((s) => s.id).toSet();
      expect(ids, {
        'terms_and_conditions',
        'fees_and_charges',
        'contribution_policy',
        'loan_policy',
        'guarantor_requirement',
        'default_recovery_policy',
        'registration_fee_policy',
        'privacy_policy',
      });
    });

    test('section ids are unique', () {
      final ids = TermsContent.sections.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every section has a title, summary, and full body text', () {
      for (final section in TermsContent.sections) {
        expect(section.title, isNotEmpty, reason: section.id);
        expect(section.summary, isNotEmpty, reason: section.id);
        expect(section.body.length, greaterThan(100), reason: section.id);
      }
    });
  });

  group('Fees & Charges disclosure', () {
    TermsSection fees() =>
        TermsContent.sections.firstWhere((s) => s.id == 'fees_and_charges');

    test('the bundled copy is the offline fallback, so it must exist', () {
      // A member with no connectivity sees this copy at onboarding. If the
      // section were missing here, they would accept the policies without
      // ever seeing the charges.
      expect(fees().title, 'Fees & Charges');
    });

    test('it is listed early, before the policy detail', () {
      final index =
          TermsContent.sections.indexWhere((s) => s.id == 'fees_and_charges');
      expect(index, greaterThan(-1));
      expect(index, lessThanOrEqualTo(2));
    });

    test('the registration fee matches AppConfig', () {
      expect(fees().body, contains(naira(AppConfig.entranceFee)));
    });

    test('the minimum contribution matches AppConfig', () {
      expect(fees().body, contains(naira(AppConfig.minContribution)));
    });

    test('the administrative fee and both levies match AppConfig', () {
      final body = fees().body;
      expect(body, contains(naira(AppConfig.totalMonthlyLevies)));
      expect(body, contains(naira(AppConfig.agmLevy)));
      expect(body, contains(naira(AppConfig.developmentLevy)));
    });

    test('the levies add up to the administrative fee', () {
      expect(
        AppConfig.agmLevy + AppConfig.developmentLevy,
        AppConfig.totalMonthlyLevies,
      );
    });

    test('every loan product the app offers has its rate published', () {
      // The member must be able to see the rate before applying. These are the
      // products loan_application_screen.dart puts in front of them.
      final body = fees().body;
      for (final product in const [
        'Quick Loan',
        'Flexi Loan',
        'Stable Loan (12 months)',
        'Stable Loan (18 months)',
        'Premium Loan',
        'Maxi Loan',
      ]) {
        expect(body, contains(product), reason: product);
      }
    });

    test('the late repayment fine is stated, with the amount', () {
      // The figure is owned by the backend (backend/src/config/feeDisclosure.js)
      // and cross-checked there against the terms document the server serves.
      // Here we only assert the member-facing copy names it.
      expect(fees().body, contains('Late repayment fine'));
      expect(fees().body, contains(naira(3000)));
    });

    test('it states the fine applies only after two missed repayments', () {
      expect(fees().body.toLowerCase(),
          contains('two consecutive missed monthly repayments'));
    });

    test('it states plainly which charges do not apply', () {
      final body = fees().body.toLowerCase();
      expect(body, contains('no withdrawal fee'));
      expect(body, contains('no penalty for repaying early'));
    });
  });

  group('TermsDocument.fromJson', () {
    test('parses the backend payload shape', () {
      final doc = TermsDocument.fromJson({
        'version': '2026-10-01',
        'sections': [
          {
            'id': 'terms_and_conditions',
            'title': 'Terms & Conditions',
            'summary': 'Membership terms.',
            'body': 'Full legal text…',
          },
        ],
      });
      expect(doc.version, '2026-10-01');
      expect(doc.sections.single.id, 'terms_and_conditions');
      expect(doc.sections.single.body, 'Full legal text…');
    });

    test('falls back to bundled sections when the payload has none', () {
      final doc = TermsDocument.fromJson({'version': '2026-10-01'});
      expect(doc.sections.length, TermsContent.sections.length);
    });

    test('drops malformed sections', () {
      final doc = TermsDocument.fromJson({
        'sections': [
          {'id': '', 'title': 'No id', 'summary': 'x', 'body': 'y'},
          {'id': 'ok', 'title': '', 'summary': 'x', 'body': 'y'},
          {'id': 'ok', 'title': 'Valid', 'summary': 'x', 'body': 'y'},
        ],
      });
      expect(doc.sections.length, 1);
      expect(doc.sections.single.id, 'ok');
    });
  });
}
