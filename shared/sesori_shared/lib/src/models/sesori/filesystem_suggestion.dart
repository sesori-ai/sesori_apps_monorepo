import "package:freezed_annotation/freezed_annotation.dart";

part "filesystem_suggestion.freezed.dart";
part "filesystem_suggestion.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class FilesystemSuggestionsRequest with _$FilesystemSuggestionsRequest {
  const factory({
    required int maxResults,
    required String? prefix,
  }) = _FilesystemSuggestionsRequest;

  factory fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionsRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class FilesystemSuggestions with _$FilesystemSuggestions {
  const factory({
    required List<FilesystemSuggestion> data,
    required String? path,

    /// The host's mounted drive roots, such as `C:\`, which the browser lists
    /// beside Home. Filled only on a Windows host and only for a request
    /// without a prefix; empty otherwise.
    // COMPATIBILITY 2026-09-24 (v1.9.1): a bridge older than this field omits
    // it, and the browser then shows no drives, as before. Make it required
    // once every supported bridge sends it.
    @Default(<String>[]) List<String> driveRoots,
  }) = _FilesystemSuggestions;

  factory fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionsFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class FilesystemSuggestion with _$FilesystemSuggestion {
  const factory({
    required String path,
    required String name,
    required bool isGitRepo,
  }) = _FilesystemSuggestion;

  factory fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionFromJson(json);
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
  const factory({
    required String parentPath,
    required String name,
  }) = _FilesystemCreateDirectoryRequest;

  factory fromJson(Map<String, dynamic> json) => _$FilesystemCreateDirectoryRequestFromJson(json);
}
