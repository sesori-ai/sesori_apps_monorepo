import "package:freezed_annotation/freezed_annotation.dart";

part "session_prompt_search.freezed.dart";
part "session_prompt_search.g.dart";

/// The body of `POST /session/prompts/search`: finds [query] in the whole text
/// of every prompt in the session's history, or in an image-only prompt's
/// attachment file name, ignoring case.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionPromptSearchRequest with _$SessionPromptSearchRequest {
  const factory({
    required String sessionId,
    required String query,
  }) = _SessionPromptSearchRequest;

  factory fromJson(Map<String, dynamic> json) => _$SessionPromptSearchRequestFromJson(json);
}

/// The prompts whose text holds the query, oldest first.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionPromptSearchResponse with _$SessionPromptSearchResponse {
  const factory({
    required List<SessionPromptSearchMatch> matches,
  }) = _SessionPromptSearchResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionPromptSearchResponseFromJson(json);
}

/// A prompt that holds the query, and the words around its first match.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionPromptSearchMatch with _$SessionPromptSearchMatch {
  const factory({
    required String messageId,
    required SessionPromptExcerpt excerpt,
  }) = _SessionPromptSearchMatch;

  factory fromJson(Map<String, dynamic> json) => _$SessionPromptSearchMatchFromJson(json);
}

/// A search [match] in a prompt's text, with the words around it on one line.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionPromptExcerpt with _$SessionPromptExcerpt {
  const factory({
    required String before,
    required String match,
    required String after,
  }) = _SessionPromptExcerpt;

  factory fromJson(Map<String, dynamic> json) => _$SessionPromptExcerptFromJson(json);
}
