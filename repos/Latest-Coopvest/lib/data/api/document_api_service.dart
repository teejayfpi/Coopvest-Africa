import 'package:dio/dio.dart';
import 'dart:io';
import '../../core/network/api_client.dart';
import '../models/document_models.dart';

/// API Service for Document Upload - KYC document submission
class DocumentApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get all documents for the current user
  Future<List<Document>> getMyDocuments() async {
    try {
      final response = await _apiClient.dio.get(
        '/documents/my-documents',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['documents'] ?? [];
        return data.map((json) => Document.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch documents');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch documents');
    }
  }

  /// Get a single document by ID
  Future<Document> getDocument(String documentId) async {
    try {
      final response = await _apiClient.dio.get(
        '/documents/$documentId',
      );

      if (response.statusCode == 200) {
        return Document.fromJson(response.data);
      }
      throw Exception('Failed to fetch document');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch document');
    }
  }

  /// Upload a document
  Future<DocumentUploadResponse> uploadDocument({
    required File file,
    required String documentType,
    required String name,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      // Validate file type
      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(extension)) {
        return DocumentUploadResponse(
          success: false,
          message: 'Invalid file type. Allowed: JPG, PNG, PDF',
        );
      }

      // Validate file size (max 10MB)
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        return DocumentUploadResponse(
          success: false,
          message: 'File size too large. Maximum size: 10MB',
        );
      }

      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        'type': documentType,
        'name': name,
      });

      final response = await _apiClient.dio.post(
        '/documents/upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return DocumentUploadResponse.fromJson(response.data);
      }
      return DocumentUploadResponse(
        success: false,
        message: response.data['message'] ?? 'Upload failed',
      );
    } on DioException catch (e) {
      return DocumentUploadResponse(
        success: false,
        message: e.response?.data['message'] ?? 'Upload failed',
      );
    }
  }

  /// Delete a document (only if pending)
  Future<bool> deleteDocument(String documentId) async {
    try {
      final response = await _apiClient.dio.delete(
        '/documents/$documentId',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to delete document');
    }
  }

  /// Get required documents for KYC
  Future<List<String>> getRequiredDocuments() async {
    try {
      final response = await _apiClient.dio.get(
        '/documents/required',
      );
      return List<String>.from(response.data['types'] ?? []);
    } on DioException catch (e) {
      return [];
    }
  }

  /// Check KYC status
  Future<Map<String, dynamic>> getKycStatus() async {
    try {
      final response = await _apiClient.dio.get(
        '/documents/kyc-status',
      );
      return {
        'isComplete': response.data['isComplete'] ?? false,
        'submittedCount': response.data['submittedCount'] ?? 0,
        'approvedCount': response.data['approvedCount'] ?? 0,
        'requiredCount': response.data['requiredCount'] ?? 0,
        'missingTypes': List<String>.from(response.data['missingTypes'] ?? []),
      };
    } on DioException catch (e) {
      return {
        'isComplete': false,
        'submittedCount': 0,
        'approvedCount': 0,
        'requiredCount': 0,
        'missingTypes': [],
      };
    }
  }

  /// Get pending documents count
  Future<int> getPendingCount() async {
    try {
      final response = await _apiClient.dio.get(
        '/documents/pending-count',
      );
      return response.data['count'] ?? 0;
    } on DioException catch (e) {
      return 0;
    }
  }
}
