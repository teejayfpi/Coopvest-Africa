import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/loan_models.dart';

/// The loan header card used to render `loan.id` — the raw 36-character UUID —
/// in an unconstrained Row, which pushed Amount and Tenure off-screen. The app
/// now shows the backend's human-readable `LN-…` reference via
/// [Loan.displayReference]. These tests pin that value and its fallback so the
/// UUID can never reappear in the UI.
void main() {
  Loan loanFrom(Map<String, dynamic> json) => Loan.fromJson(json);

  final baseJson = <String, dynamic>{
    'id': 'c6ffa8c2-37e4-4c0c-9f4c-25c8505a4a1c',
    'user_id': 'u1',
    'amount': 500000,
    'tenure': 12,
    'status': 'pending',
  };

  group('Loan.reference', () {
    test('reads loan_id from the API payload', () {
      final loan = loanFrom({...baseJson, 'loan_id': 'LN-1789968194496-582'});
      expect(loan.reference, 'LN-1789968194496-582');
      expect(loan.displayReference, 'LN-1789968194496-582');
    });

    test('accepts camelCase loanId too', () {
      final loan = loanFrom({...baseJson, 'loanId': 'LN-1-2'});
      expect(loan.displayReference, 'LN-1-2');
    });

    test('falls back to a short uppercased UUID prefix, never the full UUID', () {
      final loan = loanFrom(baseJson);
      expect(loan.displayReference, 'C6FFA8C2');
      expect(loan.displayReference.length, lessThan(loan.id.length));
    });

    test('never returns an empty display value', () {
      final loan = loanFrom({...baseJson, 'id': ''});
      expect(loan.displayReference, isNotEmpty);
    });

    test('handles a UUID shorter than 8 characters without throwing', () {
      final loan = loanFrom({...baseJson, 'id': 'abc'});
      expect(loan.displayReference, 'ABC');
    });
  });

  group('Loan JSON round-trip', () {
    test('preserves the reference through copyWith', () {
      final loan = loanFrom({...baseJson, 'loan_id': 'LN-999'});
      expect(loan.copyWith(status: 'active').reference, 'LN-999');
    });

    test('emits loan_id in toJson', () {
      final loan = loanFrom({...baseJson, 'loan_id': 'LN-777'});
      expect(loan.toJson()['loan_id'], 'LN-777');
    });
  });
}
