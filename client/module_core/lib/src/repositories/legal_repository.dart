import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../api/legal_api.dart";

export "../api/legal_api.dart" show LegalDocument;

/// Repository seam between [LegalApi] and the legal-document consumers.
///
/// The documents are static and read-only, so this passes the API response
/// through unchanged; it exists so cubits depend on a repository rather than
/// reaching into the API layer.
@lazySingleton
class LegalRepository {
  final LegalApi _api;

  LegalRepository({required LegalApi api}) : _api = api;

  Future<ApiResponse<String>> getMarkdown({required LegalDocument document}) {
    return _api.fetchMarkdown(document: document);
  }
}
