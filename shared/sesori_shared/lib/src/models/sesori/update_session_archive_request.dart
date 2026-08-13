import "package:freezed_annotation/freezed_annotation.dart";

part "update_session_archive_request.freezed.dart";

part "update_session_archive_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class UpdateSessionArchiveRequest with _$UpdateSessionArchiveRequest {
  const factory({
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) = _UpdateSessionArchiveRequest;

  factory fromJson(Map<String, dynamic> json) => _$UpdateSessionArchiveRequestFromJson(json);
}
