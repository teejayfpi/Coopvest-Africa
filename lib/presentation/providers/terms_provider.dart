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
    // The client's base URL already ends in `/api`, so this resolves to
    // `/api/v1/terms`. It previously read `/terms`, which resolved to
    // `/api/terms` — a path the server does not mount — so the request always
    // failed and the app silently used the bundled copy, never the live text.
    final data = await ref.read(apiClientProvider).get('/v1/terms');
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
