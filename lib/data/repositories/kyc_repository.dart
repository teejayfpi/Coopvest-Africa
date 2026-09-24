import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';
import 'package:dio/dio.dart';
import '../models/kyc_models.dart';

/// KYC Repository Provider
final kycRepositoryProvider = Provider<KYCRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return KYCRepository(apiClient);
});

/// KYC Repository
class KYCRepository {
  final ApiClient _apiClient;

  KYCRepository(this._apiClient);

  /// Get KYC status
  ///
  /// The backend returns `{ success, kyc: <row> }` where the row uses
  /// snake_case columns and stores structured data in JSONB fields
  /// (personal_info, employment_info, bank_info, address, date_of_birth,
  /// national_id, selfie, status, submitted_at). Map that into KYCSubmission.
  Future<KYCSubmission> getKYCStatus() async {
    try {
      // This call gates AuthGuard navigation, so pin it to the fast
      // kycStatusTimeout instead of the shared 60s apiTimeout. Without this, a
      // slow/cold-starting backend stalls the app behind a loading spinner for
      // up to a minute. On timeout/error the provider falls through to the
      // profile-driven routing below rather than dead-ending the member.
      final response = await _apiClient.get(
        '/kyc/status',
        options: Options(
          connectTimeout: AppConfig.kycStatusTimeout,
          receiveTimeout: AppConfig.kycStatusTimeout,
          sendTimeout: AppConfig.kycStatusTimeout,
        ),
      );
      final data = response is Map<String, dynamic> ? response : <String, dynamic>{};
      // The status row is nested under 'kyc'; fall back to the response itself
      // for older payloads.
      final row = (data['kyc'] as Map<String, dynamic>?) ?? data;

      String? str(dynamic v) => v == null ? null : v.toString();

      final personal = (row['personal_info'] as Map<String, dynamic>?) ?? const {};
      final employment = (row['employment_info'] as Map<String, dynamic>?) ?? const {};
      final bank = (row['bank_info'] as Map<String, dynamic>?) ?? const {};
      final selfie = (row['selfie'] as Map<String, dynamic>?) ?? const {};

      return KYCSubmission(
        dateOfBirth: str(row['date_of_birth'] ?? personal['date_of_birth']),
        // Preserve the real lifecycle status from the backend so the AuthGuard
        // can tell "genuinely not submitted" (pending) apart from a failed
        // fetch. Defaulting to 'pending' here previously caused every network
        // blip to re-trigger the KYC flow for members who had already
        // submitted.
        gender: str(personal['gender']),
        employmentType: str(employment['employment_type'] ?? employment['employmentType']) ?? '',
        organizationId: str(employment['organization_id'] ?? employment['organizationId']),
        organizationName: str(employment['organization_name'] ?? employment['organizationName']),
        jobTitle: str(employment['job_title'] ?? employment['jobTitle']) ?? '',
        monthlyIncomeRange: str(employment['monthly_income_range'] ?? employment['monthlyIncomeRange']) ?? '',
        occupation: str(employment['occupation']),
        employerName: str(employment['employer_name'] ?? employment['employerName']),
        workAddress: str(employment['work_address'] ?? employment['workAddress']),
        yearsOfEmployment: str(employment['years_of_employment'] ?? employment['yearsOfEmployment']),
        residentialAddress: str(row['address'] ?? personal['residential_address'] ?? personal['address']) ?? '',
        city: str(personal['city']),
        state: str(personal['state']),
        lga: str(personal['lga']),
        country: str(personal['country'] ?? row['country']),
        idType: str(personal['id_type'] ?? row['id_type']) ?? '',
        idNumber: str(row['national_id'] ?? personal['id_number'] ?? personal['nin']),
        idPhotoPath: str(personal['id_photo_path'] ?? personal['idPhotoPath']),
        staffId: str(personal['staff_id'] ?? personal['staffId'] ?? employment['staff_id']),
        selfiePhotoPath: str(selfie['url'] ?? selfie['path'] ?? selfie['selfie_photo_path']),
        nokName: str(personal['nok_name'] ?? personal['nokName']),
        nokRelationship: str(personal['nok_relationship'] ?? personal['nokRelationship']),
        nokPhone: str(personal['nok_phone'] ?? personal['nokPhone']),
        nokAddress: str(personal['nok_address'] ?? personal['nokAddress']),
        bankName: str(bank['bank_name'] ?? bank['bankName']),
        bankCode: str(bank['bank_code'] ?? bank['bankCode']),
        accountNumber: str(bank['account_number'] ?? bank['accountNumber']),
        accountName: str(bank['account_name'] ?? bank['accountName']),
        accountType: str(bank['account_type'] ?? bank['accountType']),
        bvn: str(bank['bvn'] ?? row['bvn']),
        contributionType: str(personal['contribution_type'] ?? personal['contributionType']) ?? 'direct_deposit',
        status: str(row['status']) ?? 'pending',
        submittedAt: row['submitted_at'] != null
            ? DateTime.tryParse(row['submitted_at'].toString())
            : null,
        approvedAt: row['verified_at'] != null
            ? DateTime.tryParse(row['verified_at'].toString())
            : null,
        rejectionReason: str(row['rejection_reason']),
      );
    } catch (e) {
      logger.e('Get KYC status error: $e');
      // Re-throw so the KYC provider can surface an error state. Previously
      // this returned a fabricated KYCSubmission with status='pending', which
      // made AuthGuard believe the member had never submitted KYC and forced
      // them back into the KYC flow on every transient backend failure (e.g.
      // Render cold starts). AuthGuard now treats an unknown/error state as
      // "do not prompt" rather than "not submitted".
      rethrow;
    }
  }

  /// Submit KYC
  ///
  /// Maps the flat KYCSubmission into the nested shape the backend expects:
  /// `{ personalInfo, address, employmentInfo, bvn, nin }`.
  Future<void> submitKYC(KYCSubmission submission) async {
    try {
      await _apiClient.post(
        '/kyc/submit',
        data: {
          'personalInfo': {
            'date_of_birth': submission.dateOfBirth,
            'gender': submission.gender,
            'residential_address': submission.residentialAddress,
            'city': submission.city,
            'state': submission.state,
            'lga': submission.lga,
            'country': submission.country ?? 'Nigeria',
            'id_type': submission.idType,
            'id_number': submission.idNumber,
            'id_photo_path': submission.idPhotoPath,
            'staff_id': submission.staffId,
            'selfie_photo_path': submission.selfiePhotoPath,
            'nok_name': submission.nokName,
            'nok_relationship': submission.nokRelationship,
            'nok_phone': submission.nokPhone,
            'nok_address': submission.nokAddress,
            'contribution_type': submission.contributionType,
          },
          'address': {
            'residential_address': submission.residentialAddress,
            'city': submission.city,
            'state': submission.state,
            'country': submission.country ?? 'Nigeria',
          },
          'employmentInfo': {
            'employment_type': submission.employmentType,
            'organization_id': submission.organizationId,
            'organization_name': submission.organizationName,
            'job_title': submission.jobTitle,
            'monthly_income_range': submission.monthlyIncomeRange,
            'occupation': submission.occupation,
            'employer_name': submission.employerName,
            'work_address': submission.workAddress,
            'years_of_employment': submission.yearsOfEmployment,
          },
          'bankInfo': {
            'bank_name': submission.bankName,
            'bank_code': submission.bankCode,
            'account_number': submission.accountNumber,
            'account_name': submission.accountName,
            'account_type': submission.accountType,
            'bvn': submission.bvn,
          },
          'bvn': submission.bvn,
          'nin': submission.idNumber,
          'idType': submission.idType,
          'idNumber': submission.idNumber,
          'selfieUrl': submission.selfiePhotoPath,
          'idPhotoPath': submission.idPhotoPath,
        },
      );
    } catch (e) {
      logger.e('Submit KYC error: $e');
      rethrow;
    }
  }

  /// Set or switch the member's contribution channel
  /// ('direct_deposit' | 'salary_deduction'). Switching to salary deduction
  /// requires employment details and re-submits the KYC for admin review.
  Future<KYCSubmission> setContributionType(
    String contributionType, {
    Map<String, dynamic>? employmentInfo,
  }) async {
    try {
      await _apiClient.post(
        '/kyc/contribution-type',
        data: {
          'contribution_type': contributionType,
          if (employmentInfo != null) 'employmentInfo': employmentInfo,
        },
      );
      // Refresh from the authoritative status endpoint so the caller gets
      // the fully-mapped submission (same shape as getKYCStatus).
      //
      // This MUST be awaited. Returning the Future directly from inside the
      // try block meant the try/catch had already exited by the time the
      // request completed, so any failure from getKYCStatus() bypassed the
      // catch below entirely and surfaced to the caller as an unhandled
      // error with no log line. Awaiting makes the catch actually catch it.
      return await getKYCStatus();
    } catch (e) {
      logger.e('Set contribution type error: $e');
      rethrow;
    }
  }

  /// Organisations a member may pick for salary deduction.
  ///
  /// Hits `/organizations/selectable`, which returns only active organisations
  /// with deduction enabled — offering an employer that is not set up to remit
  /// would leave the member unable to contribute at all.
  ///
  /// The previous implementation called `/organizations`, a path that was never
  /// mounted on the backend, and read `data['data']` when the payload uses
  /// `organizations`. Both faults were swallowed by the caller's best-effort
  /// try/catch, which is why the picker silently fell back to a hardcoded list.
  Future<List<Organization>> getOrganizations({String? search}) async {
    try {
      final response = await _apiClient.get(
        '/organizations/selectable',
        queryParameters: {
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final data = response as Map<String, dynamic>;
      final raw = data['organizations'] ?? data['data'];
      if (raw is! List) return const [];

      return raw
          .whereType<Map>()
          .map((item) => Organization.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      logger.e('Get organizations error: $e');
      rethrow;
    }
  }

  /// Upload ID document photo via the dedicated multipart KYC upload route.
  ///
  /// The backend uploads the file to the private `kyc-documents` Supabase
  /// Storage bucket, records it against `kyc_documents.front_image_url`
  /// (or `back_image_url` when [side] is 'back'), and returns a signed URL.
  Future<String> uploadIDDocument(String filePath, {String side = 'front'}) async {
    return _uploadKycImage(filePath, type: 'id_document', side: side);
  }

  /// Upload selfie via the dedicated multipart KYC upload route.
  ///
  /// The backend stores the file in the `kyc-documents` bucket and records the
  /// signed URL in the `kyc.selfie` JSONB column.
  Future<String> uploadSelfie(String filePath) async {
    return _uploadKycImage(filePath, type: 'selfie');
  }

  /// Uploads a KYC image (selfie or id_document) to POST /kyc/upload.
  ///
  /// Unlike the old implementation, this does NOT fall back to a local device
  /// path on failure — doing so made the KYC flow silently "succeed" while no
  /// image was ever stored (the local path is meaningless to the backend).
  /// Instead, failures are surfaced to the caller so the user is asked to
  /// retry, and the KYC submission is not marked complete with a missing photo.
  Future<String> _uploadKycImage(String filePath,
      {required String type, String side = 'front'}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'type': type,
        if (type == 'id_document') 'side': side,
      });
      final response = await _apiClient.post(
        '/kyc/upload',
        data: formData,
      );
      final url = (response is Map ? response['url'] : null)?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Upload succeeded but no URL was returned by the server.');
      }
      return url;
    } catch (e) {
      logger.e('KYC $type upload failed: $e');
      rethrow;
    }
  }

  /// Upload avatar/profile picture
  Future<String> uploadAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });

      final response = await _apiClient.post(
        '/kyc/upload-avatar',
        data: formData,
      );

      return response['path'] as String;
    } catch (e) {
      logger.e('Upload avatar error: $e');
      rethrow;
    }
  }

  /// Request organization approval
  ///
  /// The endpoint now exists (it previously 404'd silently, so the member was
  /// told nothing and no admin ever saw the request). Returns the backend's
  /// status: `pending` when the employer must be enrolled, or `enrolled` when
  /// it turns out they already are and the member can simply select them.
  Future<Map<String, dynamic>> requestOrganizationApproval(String organizationName) async {
    try {
      final response = await _apiClient.post(
        '/organizations/request-approval',
        data: {'organization_name': organizationName},
      );
      if (response is Map<String, dynamic>) return response;
      if (response is Map) return Map<String, dynamic>.from(response);
      return const {'success': true, 'status': 'pending'};
    } catch (e) {
      logger.e('Request organization approval error: $e');
      rethrow;
    }
  }

  /// The member's own organisation and deduction status, so the contribution
  /// screen can say "Salary deduction via X" instead of offering a payment it
  /// makes no sense to offer.
  Future<Map<String, dynamic>> getMyOrganizationStatus() async {
    try {
      final response = await _apiClient.get('/organizations/me');
      if (response is Map<String, dynamic>) return response;
      if (response is Map) return Map<String, dynamic>.from(response);
      return const {};
    } catch (e) {
      logger.e('Get my organization status error: $e');
      rethrow;
    }
  }

  /// Get KYC submission history
  Future<List<Map<String, dynamic>>> getSubmissionHistory() async {
    try {
      final response = await _apiClient.get('/kyc/history');
      final data = response as Map<String, dynamic>;
      return (data['data'] as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      logger.e('Get KYC history error: $e');
      rethrow;
    }
  }
}
