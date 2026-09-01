import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../data/models/terms_content.dart';

/// Provides the current Terms & Conditions document.
///
/// Fetches from the backend (`GET /api/v1/terms`) so legal text can be
/// updated without an app release; falls back to the bundled document when
/// the request fails.
final termsDocumentProvider = FutureProvider<TermsDocument>((ref) async {
  try {
    final data = await ref.read(apiClientProvider).get('/terms');
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['sections'] is List &&
        (data['sections'] as List).isNotEmpty) {
      return TermsDocument.fromJson(data);
    }
  } catch (_) {
    // Fall through to the bundled document.
  }
  return TermsContent.bundled();
});
