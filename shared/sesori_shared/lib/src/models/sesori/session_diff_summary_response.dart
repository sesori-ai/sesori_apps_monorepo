import "package:freezed_annotation/freezed_annotation.dart";

part "session_diff_summary_response.freezed.dart";
part "session_diff_summary_response.g.dart";

/// The session's line totals across every changed file, from `git diff
/// --numstat` without the files' contents.
@Freezed(fromJson: true, toJson: true)
sealed class SessionDiffSummaryResponse with _$SessionDiffSummaryResponse {
  const factory({
    required int additions,
    required int deletions,
  }) = _SessionDiffSummaryResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionDiffSummaryResponseFromJson(json);
}

enum SessionDiffSummaryErrorCode() {
  sessionNotFound,
  unknown,
}

/// The body of a failed `/session/diff-summary` request. Its presence tells a
/// missing session apart from the bare 404 an older bridge returns for the
/// unknown route.
@Freezed(fromJson: true, toJson: true)
sealed class SessionDiffSummaryErrorResponse with _$SessionDiffSummaryErrorResponse {
  const factory({
    @JsonKey(unknownEnumValue: SessionDiffSummaryErrorCode.unknown) required SessionDiffSummaryErrorCode code,
  }) = _SessionDiffSummaryErrorResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionDiffSummaryErrorResponseFromJson(json);
}
