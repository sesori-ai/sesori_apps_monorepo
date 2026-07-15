import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class FilesystemApi {
  final RelayHttpApiClient _client;

  FilesystemApi({required RelayHttpApiClient client}) : _client = client;

  Future<ApiResponse<FilesystemSuggestions>> getSuggestions({
    required String? prefix,
  }) {
    return _client.post(
      "/filesystem/suggestions",
      body: FilesystemSuggestionsRequest(prefix: prefix, maxResults: 50),
      fromJson: FilesystemSuggestions.fromJson,
    );
  }
}
