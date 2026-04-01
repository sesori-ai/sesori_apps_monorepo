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
