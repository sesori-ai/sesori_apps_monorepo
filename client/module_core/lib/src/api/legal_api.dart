import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

/// A legal document the backend publishes as markdown.
///
/// The same documents are also served as web pages on `sesori.com`; the app
/// renders the markdown in-place instead of leaving for the browser.
enum LegalDocument(this.path) {
  terms("/terms"),
  privacy("/privacy");

  /// Path of the document's markdown endpoint, relative to [authBaseUrl].
  final String path;
}

/// API layer for the public legal documents on the auth server.
///
/// The endpoints serve raw markdown and need no token, so this uses the
/// unauthenticated [HttpApiClient] rather than [AuthenticatedHttpApiClient].
@lazySingleton
class LegalApi({required HttpApiClient client}) {
  final HttpApiClient _client;

  this : _client = client;

  Future<ApiResponse<String>> fetchMarkdown({required LegalDocument document}) {
    return _client.getText(url: Uri.parse("$authBaseUrl${document.path}"));
  }
}
