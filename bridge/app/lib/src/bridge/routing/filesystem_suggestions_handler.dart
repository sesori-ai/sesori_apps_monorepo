import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "request_handler.dart";

/// Handles `POST /filesystem/suggestions` — lists child directories of a given prefix path.
class FilesystemSuggestionsHandler extends BodyRequestHandler<FilesystemSuggestionsRequest, FilesystemSuggestions> {
  final FilesystemRepository _filesystemRepository;

  FilesystemSuggestionsHandler({required FilesystemRepository filesystemRepository})
    : _filesystemRepository = filesystemRepository,
      super(
        HttpMethod.post,
        "/filesystem/suggestions",
        fromJson: FilesystemSuggestionsRequest.fromJson,
      );

  @override
  Future<FilesystemSuggestions> handle(
    RelayRequest request, {
    required FilesystemSuggestionsRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final prefix = body.prefix ?? Platform.environment["HOME"] ?? "/";

    if (!prefix.startsWith("/")) {
      throw buildErrorResponse(request, 400, "prefix must be an absolute path");
    }
    if (prefix.contains("..")) {
      throw buildErrorResponse(request, 400, "path traversal not allowed");
    }

    try {
      return _filesystemRepository.listSuggestions(prefix: prefix, maxResults: body.maxResults);
    } on FilesystemPermissionDeniedException {
      throw buildErrorResponse(request, 403, "permission denied: $prefix");
    } on FilesystemDirectoryNotFoundException {
      throw buildErrorResponse(request, 404, "directory not found");
    } on FileSystemException catch (error, stackTrace) {
      Log.w("FilesystemSuggestionsHandler: failed to list $prefix", error, stackTrace);
      throw buildErrorResponse(request, 500, "failed to list filesystem suggestions");
    }
  }
}
