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

  Future<ApiResponse<FilesystemSuggestion>> createDirectory({
    required String parentPath,
    required String name,
  }) {
    return _client.post(
      "/filesystem/directory",
      body: FilesystemCreateDirectoryRequest(parentPath: parentPath, name: name),
      fromJson: FilesystemSuggestion.fromJson,
    );
  }
}
