import "dart:convert";
import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /filesystem/suggestions` — lists child directories of a given prefix path.
class FilesystemSuggestionsHandler extends RequestHandler {
  static const _maxResults = 20;

  FilesystemSuggestionsHandler() : super(HttpMethod.get, "/filesystem/suggestions");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    var prefix = queryParams["prefix"];
    if (prefix == null || prefix.isEmpty) {
      prefix = Platform.environment["HOME"] ?? "/";
    }

    // Validate path
    if (!prefix.startsWith("/")) {
      return buildErrorResponse(request, 400, "prefix must be an absolute path");
    }
    if (prefix.contains("..")) {
      return buildErrorResponse(request, 400, "path traversal not allowed");
    }

    // List child directories
    final dir = Directory(prefix);
    if (!dir.existsSync()) {
      return buildOkJsonResponse(request, "[]");
    }

    try {
      final entries =
          dir
              .listSync(followLinks: false)
              .whereType<Directory>()
              .where((d) => !d.path.split("/").last.startsWith("."))
              .take(_maxResults)
              .map((d) {
                final name = d.path.split("/").last;
                final isGitRepo = Directory("${d.path}/.git").existsSync();
                return FilesystemSuggestion(path: d.path, name: name, isGitRepo: isGitRepo);
              })
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      return buildOkJsonResponse(request, jsonEncode(entries.map((e) => e.toJson()).toList()));
    } on FileSystemException {
      return buildOkJsonResponse(request, "[]");
    }
  }
}
