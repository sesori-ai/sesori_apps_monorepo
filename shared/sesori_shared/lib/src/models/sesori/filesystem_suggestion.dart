import "package:freezed_annotation/freezed_annotation.dart";

part "filesystem_suggestion.freezed.dart";
part "filesystem_suggestion.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class FilesystemSuggestionsRequest with _$FilesystemSuggestionsRequest {
  const factory FilesystemSuggestionsRequest({
    required int maxResults,
    required String? prefix,
  }) = _FilesystemSuggestionsRequest;

  factory FilesystemSuggestionsRequest.fromJson(Map<String, dynamic> json) =>
      _$FilesystemSuggestionsRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class FilesystemSuggestions with _$FilesystemSuggestions {
  const factory FilesystemSuggestions({
    required List<FilesystemSuggestion> data,
    required String? path,
  }) = _FilesystemSuggestions;

  factory FilesystemSuggestions.fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionsFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class FilesystemSuggestion with _$FilesystemSuggestion {
  const factory FilesystemSuggestion({
    required String path,
    required String name,
    required bool isGitRepo,
  }) = _FilesystemSuggestion;

  factory FilesystemSuggestion.fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionFromJson(json);
}

/// Creates a plain directory named [name] inside [parentPath] on the bridge's
/// host, for the directory browser's "create new folder" action.
///
/// The name is sent apart from the parent so the bridge — the only side that
/// knows its own path separator — joins them, and can reject a name that would
/// escape [parentPath] instead of silently creating a nested tree.
///
/// This only creates the directory; registering it as a project is a separate
/// `/project/open` call.
@Freezed(fromJson: true, toJson: true)
sealed class FilesystemCreateDirectoryRequest with _$FilesystemCreateDirectoryRequest {
  const factory FilesystemCreateDirectoryRequest({
    required String parentPath,
    required String name,
  }) = _FilesystemCreateDirectoryRequest;

  factory FilesystemCreateDirectoryRequest.fromJson(Map<String, dynamic> json) =>
      _$FilesystemCreateDirectoryRequestFromJson(json);
}
