import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `POST /filesystem/suggestions` — lists child directories of a given prefix path.
class FilesystemSuggestionsHandler extends BodyRequestHandler<FilesystemSuggestionsRequest, FilesystemSuggestions> {
  FilesystemSuggestionsHandler()
    : super(
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

    // Validate path
    if (!prefix.startsWith("/")) {
      throw buildErrorResponse(request, 400, "prefix must be an absolute path");
    }
    if (prefix.contains("..")) {
      throw buildErrorResponse(request, 400, "path traversal not allowed");
    }

    // List child directories
    final dir = Directory(prefix);
    if (!dir.existsSync()) {
      throw buildErrorResponse(request, 404, "directory not found");
    }

    try {
      final entries =
          dir
              .listSync(followLinks: false)
              .whereType<Directory>()
              .where((d) => !d.path.split("/").last.startsWith("."))
              .take(body.maxResults)
              .map((d) {
                final name = d.path.split("/").last;
                final isGitRepo = Directory("${d.path}/.git").existsSync();
                return FilesystemSuggestion(path: d.path, name: name, isGitRepo: isGitRepo);
              })
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      final suggestions = FilesystemSuggestions(data: entries);

      return suggestions;
    } on FileSystemException {
      throw buildErrorResponse(request, 500, "failed to list filesystem suggestions");
    }
  }
}
