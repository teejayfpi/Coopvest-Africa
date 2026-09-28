import 'package:coopvest_mobile/data/models/kyc_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// `GET /kyc/status` returns a provisional 'pending' row (the backend calls
/// getOrCreateKyc on first read), so the response object is never null. A
/// guard written as `submission ??= await _restoreDraft()` could therefore
/// never run, silently disabling the documented "resume my KYC draft" feature.
///
/// These tests pin the replacement predicate: a locally saved draft may only
/// be restored while the server row is still untouched, so it can never
/// overwrite data the server already holds.
void main() {
  group('KYCSubmission.isUntouchedServerRow', () {
    test('an empty provisional row is treated as untouched', () {
      const submission = KYCSubmission(status: 'pending');
      expect(submission.isUntouchedServerRow, isTrue);
    });

    test('a row carrying a member-entered field is not untouched', () {
      const withDob = KYCSubmission(status: 'pending', dateOfBirth: '1990-05-12');
      const withAddress = KYCSubmission(status: 'pending', residentialAddress: '3 Marina Rd');
      const withId = KYCSubmission(status: 'pending', idNumber: '12345678901');

      expect(withDob.isUntouchedServerRow, isFalse);
      expect(withAddress.isUntouchedServerRow, isFalse);
      expect(withId.isUntouchedServerRow, isFalse);
    });

    test('a row past pending is never treated as untouched', () {
      const submitted = KYCSubmission(status: 'submitted');
      const approved = KYCSubmission(status: 'approved');
      const rejected = KYCSubmission(status: 'rejected');

      expect(submitted.isUntouchedServerRow, isFalse);
      expect(approved.isUntouchedServerRow, isFalse);
      expect(rejected.isUntouchedServerRow, isFalse);
    });
  });
}
