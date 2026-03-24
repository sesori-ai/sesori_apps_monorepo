import "package:freezed_annotation/freezed_annotation.dart";

part "filesystem_suggestion.freezed.dart";
part "filesystem_suggestion.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class FilesystemSuggestion with _$FilesystemSuggestion {
  const factory FilesystemSuggestion({
    required String path,
    required String name,
    required bool isGitRepo,
  }) = _FilesystemSuggestion;

  factory FilesystemSuggestion.fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionFromJson(json);
}
