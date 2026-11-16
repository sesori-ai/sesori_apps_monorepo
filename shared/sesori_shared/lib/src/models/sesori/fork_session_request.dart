import "package:freezed_annotation/freezed_annotation.dart";

part "fork_session_request.freezed.dart";
part "fork_session_request.g.dart";

/// Request body for `POST /session/fork`: a new session whose conversation is
/// [sessionId]'s up to [point], in the same directory or worktree. The origin
/// is left unchanged. Answers the new `Session`; refusals answer
/// `SessionBranchErrorResponse`.
@Freezed(fromJson: true, toJson: true)
sealed class ForkSessionRequest with _$ForkSessionRequest {
  const factory({
    required String sessionId,
    required ForkPoint point,
  }) = _ForkSessionRequest;

  factory fromJson(Map<String, dynamic> json) => _$ForkSessionRequestFromJson(json);
}

/// Where a fork cuts its origin's conversation. Fork points are turn
/// boundaries by the shared prompt-turn rule.
@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class ForkPoint with _$ForkPoint {
  /// Keeps the conversation through the end of the finished turn that holds
  /// [messageId]: an agent reply, or a follow-up sent while that turn ran.
  @FreezedUnionValue("afterMessage")
  const factory afterMessage({required String messageId}) = ForkPointAfterMessage;

  /// Keeps everything before the turn opened by [messageId], the user message
  /// that starts that turn. On the session's first turn, this keeps nothing.
  @FreezedUnionValue("beforeMessage")
  const factory beforeMessage({required String messageId}) = ForkPointBeforeMessage;

  /// Keeps the conversation through the latest finished turn.
  @FreezedUnionValue("latest")
  const factory latest() = ForkPointLatest;

  factory fromJson(Map<String, dynamic> json) => _$ForkPointFromJson(json);
}
