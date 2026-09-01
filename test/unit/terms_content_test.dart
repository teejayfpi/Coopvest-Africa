import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/terms_content.dart';

void main() {
  group('TermsContent bundled document', () {
    test('has a version and all seven policies', () {
      final doc = TermsContent.bundled();
      expect(doc.version, TermsContent.version);
      expect(doc.sections.length, 7);
    });

    test('contains every required policy id', () {
      final ids = TermsContent.sections.map((s) => s.id).toSet();
      expect(ids, {
        'terms_and_conditions',
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
