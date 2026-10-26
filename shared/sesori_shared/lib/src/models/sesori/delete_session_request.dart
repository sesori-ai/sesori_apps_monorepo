import "package:freezed_annotation/freezed_annotation.dart";

part "delete_session_request.freezed.dart";

part "delete_session_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class DeleteSessionRequest with _$DeleteSessionRequest {
  const factory({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
    // COMPATIBILITY 2026-10-25 (v1.9.2): Older apps omit deleteSessionFolder and never warn that a session's files go with it, so their deletes keep the folder. Require the field once no supported app omits it.
    @Default(false) bool deleteSessionFolder,
  }) = _DeleteSessionRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeleteSessionRequestFromJson(json);
}
