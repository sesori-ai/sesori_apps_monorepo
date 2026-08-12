import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class FilesystemApi({required RelayHttpApiClient client}) {
  /// How many child directories one browse request asks the bridge for.
  ///
  /// The bridge sorts by name and truncates to this many, so the value is a
  /// ceiling on what the browser can reach in a folder — not a page size, since
  /// there is no cursor to request the rest. It is set high enough that ordinary
  /// folders list completely, and kept bounded only to cap the response payload
  /// for pathological directories (`node_modules` and the like), at roughly
  /// 150 bytes per entry.
  static const _browseResultLimit = 1000;

  final RelayHttpApiClient _client;

  this : _client = client;

  Future<ApiResponse<FilesystemSuggestions>> getSuggestions({
    required String? prefix,
  }) {
    return _client.post(
      "/filesystem/suggestions",
      body: FilesystemSuggestionsRequest(prefix: prefix, maxResults: _browseResultLimit),
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
