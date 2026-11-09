import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class FilesystemApi({required final RelayHttpApiClient _client}) {
  /// A preview can be tens of megabytes, so a slow link gets as long as a
  /// transcript attachment download.
  static const _previewTimeout = Duration(minutes: 2);

  /// How many child directories one browse request asks the bridge for.
  ///
  /// The bridge sorts by name and truncates to this many, so the value is a
  /// ceiling on what the browser can reach in a folder — not a page size, since
  /// there is no cursor to request the rest. It is set high enough that ordinary
  /// folders list completely, and kept bounded only to cap the response payload
  /// for pathological directories (`node_modules` and the like), at roughly
  /// 150 bytes per entry.
  static const _browseResultLimit = 1000;

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

  /// Reads a preview of the file at the absolute [path] on the bridge's computer.
  ///
  /// An image preview can be tens of megabytes of base64, so it decodes off the
  /// UI isolate, and the file's content stays out of error reports.
  Future<ApiResponse<FilePreviewResponse>> readFilePreview({required String path}) {
    return _client.postDecodedInBackground(
      path: "/filesystem/file",
      // A bridge that predates PDF previews ignores acceptsPdf and answers
      // unsupported for a PDF, so the app shows it as it shows any other
      // binary file: "This file can't be previewed".
      body: FilePreviewRequest(path: path, acceptsPdf: true),
      fromJson: FilePreviewResponse.fromJson,
      sensitiveResponse: true,
      timeout: _previewTimeout,
    );
  }
}
