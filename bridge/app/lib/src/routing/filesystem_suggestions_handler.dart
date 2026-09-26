import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "request_handler.dart";

/// Handles `POST /filesystem/suggestions` — lists child directories of a given
/// prefix path, plus a Windows host's drive roots when there is no prefix.
class FilesystemSuggestionsHandler({required final FilesystemRepository _filesystemRepository})
    extends BodyRequestHandler<FilesystemSuggestionsRequest, FilesystemSuggestions> {
  this
    : super(
        HttpMethod.post,
        "/filesystem/suggestions",
        fromJson: FilesystemSuggestionsRequest.fromJson,
      );

  @override
  Future<FilesystemSuggestions> handle(
    RelayRequest request, {
    required FilesystemSuggestionsRequest body,
  }) async {
    final prefix = body.prefix;
    if (prefix != null) {
      if (!p.isAbsolute(prefix)) {
        throw buildErrorResponse(request, 400, "prefix must be an absolute path");
      }
      if (p.split(prefix).contains("..")) {
        throw buildErrorResponse(request, 400, "path traversal not allowed");
      }
    }

    try {
      return await _filesystemRepository.listBrowserSuggestions(prefix: prefix, maxResults: body.maxResults);
    } on FilesystemPermissionDeniedException catch (error) {
      throw buildErrorResponse(request, 403, "permission denied: ${error.path}");
    } on FilesystemDirectoryNotFoundException {
      throw buildErrorResponse(request, 404, "directory not found");
    } on FileSystemException catch (error, stackTrace) {
      Log.w("FilesystemSuggestionsHandler: failed to list ${prefix ?? "the default browse path"}", error, stackTrace);
      throw buildErrorResponse(request, 500, "failed to list filesystem suggestions");
    }
  }
}
