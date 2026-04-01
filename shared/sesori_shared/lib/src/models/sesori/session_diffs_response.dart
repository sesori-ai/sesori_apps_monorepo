import "package:freezed_annotation/freezed_annotation.dart";

import "file_diff.dart";

part "session_diffs_response.freezed.dart";
part "session_diffs_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SessionDiffsResponse with _$SessionDiffsResponse {
  const factory SessionDiffsResponse({
    required List<FileDiff> diffs,
  }) = _SessionDiffsResponse;

  factory SessionDiffsResponse.fromJson(Map<String, dynamic> json) => _$SessionDiffsResponseFromJson(json);
}
