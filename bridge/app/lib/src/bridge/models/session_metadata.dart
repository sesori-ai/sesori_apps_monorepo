import "package:freezed_annotation/freezed_annotation.dart";

part "session_metadata.freezed.dart";
part "session_metadata.g.dart";

@freezed
sealed class SessionMetadata with _$SessionMetadata {
  const factory({
    required String title,
    required String branchName,
    required String worktreeName,
  }) = _SessionMetadata;

  factory fromJson(Map<String, dynamic> json) => _$SessionMetadataFromJson(json);
}
