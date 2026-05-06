import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/document_api_service.dart';
import '../../data/models/document_models.dart';
import 'dart:io';

/// Document State
class DocumentState {
  final List<Document> documents;
  final Map<String, dynamic> kycStatus;
  final bool isLoading;
  final bool isUploading;
  final double uploadProgress;
  final String? error;
  final String? uploadError;

  DocumentState({
    this.documents = const [],
    this.kycStatus = const {
      'isComplete': false,
      'submittedCount': 0,
      'approvedCount': 0,
      'requiredCount': 0,
      'missingTypes': [],
    },
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.error,
    this.uploadError,
  });

  DocumentState copyWith({
    List<Document>? documents,
    Map<String, dynamic>? kycStatus,
    bool? isLoading,
    bool? isUploading,
    double? uploadProgress,
    String? error,
    String? uploadError,
  }) {
    return DocumentState(
      documents: documents ?? this.documents,
      kycStatus: kycStatus ?? this.kycStatus,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error ?? this.error,
      uploadError: uploadError ?? this.uploadError,
    );
  }

  // Getters
  int get pendingCount => documents.where((d) => d.status == 'pending').length;
  int get approvedCount => documents.where((d) => d.status == 'approved').length;
  int get rejectedCount => documents.where((d) => d.status == 'rejected').length;
  bool get isKycComplete => kycStatus['isComplete'] ?? false;
  String get kyycStatus => kycStatus['status'] ?? 'unknown';
}

/// Document Provider
class DocumentProvider extends StateNotifier<DocumentState> {
  final DocumentApiService _apiService = DocumentApiService();

  DocumentProvider() : super(DocumentState());

  Future<void> loadDocuments() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final documents = await _apiService.getMyDocuments();
      state = state.copyWith(
        documents: documents,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadKycStatus() async {
    try {
      final kycStatus = await _apiService.getKycStatus();
      state = state.copyWith(kycStatus: kycStatus);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([
        loadDocuments(),
        loadKycStatus(),
      ]);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> uploadDocument({
    required File file,
    required String documentType,
    required String name,
  }) async {
    state = state.copyWith(isUploading: true, uploadProgress: 0, uploadError: null);
    try {
      final response = await _apiService.uploadDocument(
        file: file,
        documentType: documentType,
        name: name,
      );

      if (response.success) {
        // Reload documents after successful upload
        await loadDocuments();
        await loadKycStatus();
        state = state.copyWith(
          isUploading: false,
          uploadProgress: 1,
        );
        return true;
      } else {
        state = state.copyWith(
          isUploading: false,
          uploadError: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        uploadError: e.toString(),
      );
      return false;
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      final success = await _apiService.deleteDocument(documentId);
      if (success) {
        await loadDocuments();
        await loadKycStatus();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// Document Provider
final documentProvider =
    StateNotifierProvider<DocumentProvider, DocumentState>((ref) {
  return DocumentProvider();
});

/// Uploaded File Provider (for selected file in upload screen)
final uploadedFileProvider = StateProvider<File?>((ref) {
  return null;
});

/// Selected Document Provider
final selectedDocumentProvider = StateProvider<Document?>((ref) {
  return null;
});
