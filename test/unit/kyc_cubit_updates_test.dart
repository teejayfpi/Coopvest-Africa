import 'package:coopvest_mobile/core/network/api_client.dart';
import 'package:coopvest_mobile/data/models/kyc_models.dart';
import 'package:coopvest_mobile/data/repositories/kyc_repository.dart';
import 'package:coopvest_mobile/presentation/providers/kyc_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the silent-save-drop bug: every update*() method in
/// KYCCubit used to start with `if (current == null) return;`, so a member
/// whose submission had not loaded (status fetch failed or never ran) could
/// fill in all six KYC screens and have every field silently discarded while
/// navigation proceeded. Updates must now always apply.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KYCCubit cubit;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cubit = KYCCubit(KYCRepository(ApiClient()));
  });

  tearDown(() => cubit.dispose());

  group('KYCCubit updates never silently no-op', () {
    test('state starts with an empty draft, not null', () {
      expect(cubit.state.submission, isNotNull);
      expect(cubit.state.submission!.residentialAddress, '');
      expect(cubit.state.submission!.status, 'draft');
    });

    test('updatePersonalDetails applies on a fresh state', () {
      cubit.updatePersonalDetails(dateOfBirth: '1990-05-12', gender: 'male');
      expect(cubit.state.submission!.dateOfBirth, '1990-05-12');
      expect(cubit.state.submission!.gender, 'male');
    });

    test('updateEmploymentDetails applies on a fresh state', () {
      cubit.updateEmploymentDetails(
        employmentType: 'employed',
        jobTitle: 'Engineer',
        monthlyIncomeRange: '100k-200k',
      );
      final s = cubit.state.submission!;
      expect(s.employmentType, 'employed');
      expect(s.jobTitle, 'Engineer');
      expect(s.monthlyIncomeRange, '100k-200k');
    });

    test('updateAddress applies on a fresh state', () {
      cubit.updateAddress(
          residentialAddress: '12 Broad St', city: 'Lagos', stateValue: 'Lagos');
      expect(cubit.state.submission!.residentialAddress, '12 Broad St');
      expect(cubit.state.submission!.city, 'Lagos');
    });

    test('updateIDDetails applies on a fresh state', () {
      cubit.updateIDDetails(idType: 'nin', idNumber: '12345678901');
      expect(cubit.state.submission!.idType, 'nin');
      expect(cubit.state.submission!.idNumber, '12345678901');
    });

    test('updateNextOfKin applies on a fresh state', () {
      cubit.updateNextOfKin(nokName: 'Ada', nokPhone: '08012345678');
      expect(cubit.state.submission!.nokName, 'Ada');
      expect(cubit.state.submission!.nokPhone, '08012345678');
    });

    test('updateBankDetails applies on a fresh state', () {
      cubit.updateBankDetails(
          bankName: 'GTBank', accountNumber: '0123456789');
      expect(cubit.state.submission!.bankName, 'GTBank');
      expect(cubit.state.submission!.accountNumber, '0123456789');
    });

    test('sequential updates across screens accumulate in one draft', () {
      cubit.updatePersonalDetails(dateOfBirth: '1985-01-01', gender: 'female');
      cubit.updateAddress(residentialAddress: '3 Marina Rd');
      cubit.updateBankDetails(bankName: 'Kuda', accountNumber: '2000000001');
      final s = cubit.state.submission!;
      expect(s.dateOfBirth, '1985-01-01');
      expect(s.residentialAddress, '3 Marina Rd');
      expect(s.bankName, 'Kuda');
      expect(s.accountNumber, '2000000001');
    });
  });
}
