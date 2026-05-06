import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Future<KYCSubmission> getKYCStatus() async {
    try {
      final response = await _apiClient.get('/kyc/status');
      return KYCSubmission.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      logger.e('Get KYC status error: $e');
      rethrow;
    }
  }

  /// Submit KYC
  Future<void> submitKYC(KYCSubmission submission) async {
    try {
      await _apiClient.post(
        '/kyc/submit',
        data: submission.toJson(),
      );
    } catch (e) {
      logger.e('Submit KYC error: $e');
      rethrow;
    }
  }

  /// Get organizations
  Future<List<Organization>> getOrganizations({
    String? search,
    String? category,
  }) async {
    try {
      final response = await _apiClient.get(
        '/organizations',
        queryParameters: {
          if (search != null) 'search': search,
          if (category != null) 'category': category,
        },
      );

      final data = response as Map<String, dynamic>;
      final organizations = (data['data'] as List)
          .map((item) => Organization.fromJson(item as Map<String, dynamic>))
          .toList();

      return organizations;
    } catch (e) {
      logger.e('Get organizations error: $e');
      rethrow;
    }
  }

  /// Upload ID document
  Future<String> uploadIDDocument(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(filePath),
      });

      final response = await _apiClient.post(
        '/kyc/upload-id',
        data: formData,
      );

      return response['path'] as String;
    } catch (e) {
      logger.e('Upload ID document error: $e');
      rethrow;
    }
  }

  /// Upload selfie
  Future<String> uploadSelfie(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'selfie': await MultipartFile.fromFile(filePath),
      });

      final response = await _apiClient.post(
        '/kyc/upload-selfie',
        data: formData,
      );

      return response['path'] as String;
    } catch (e) {
      logger.e('Upload selfie error: $e');
      rethrow;
    }
  }

  /// Request organization approval
  Future<void> requestOrganizationApproval(String organizationName) async {
    try {
      await _apiClient.post(
        '/organizations/request-approval',
        data: {'organization_name': organizationName},
      );
    } catch (e) {
      logger.e('Request organization approval error: $e');
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
