import "package:freezed_annotation/freezed_annotation.dart";

part "delete_session_request.freezed.dart";

part "delete_session_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class DeleteSessionRequest with _$DeleteSessionRequest {
  const factory DeleteSessionRequest({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) = _DeleteSessionRequest;

  factory DeleteSessionRequest.fromJson(Map<String, dynamic> json) => _$DeleteSessionRequestFromJson(json);
}
