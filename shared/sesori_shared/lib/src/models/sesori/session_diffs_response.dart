import "package:freezed_annotation/freezed_annotation.dart";

import "file_diff.dart";

part "session_diffs_response.freezed.dart";
part "session_diffs_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SessionDiffsResponse with _$SessionDiffsResponse {
  const factory({
    required List<FileDiff> diffs,
  }) = _SessionDiffsResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionDiffsResponseFromJson(json);
}
