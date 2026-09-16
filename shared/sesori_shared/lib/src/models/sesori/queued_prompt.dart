import "package:freezed_annotation/freezed_annotation.dart";

part "queued_prompt.freezed.dart";

part "queued_prompt.g.dart";

/// Dispatch ownership of an accepted prompt awaiting its visible user echo.
/// Unknown peers cannot establish whether cancellation is still possible.
enum QueuedPromptDispatchState() {
  unknown,
  queued,
  dispatched,
}

/// An accepted prompt retained until its user message becomes visible.
/// [QueuedPromptDispatchState.queued] reports pre-dispatch ownership;
/// [QueuedPromptDispatchState.unknown] still allows best-effort cancellation
/// on older peers. [QueuedPromptDispatchState.dispatched] disables that action.
/// Only a successful cancellation response confirms the prompt was cancelled.
@Freezed(fromJson: true, toJson: true)
sealed class QueuedSessionPrompt with _$QueuedSessionPrompt {
  const factory({
    /// The prompt id: client-supplied `SendPromptRequest.promptId`, or a
    /// bridge-generated fallback for clients that predate it.
    required String id,

    // COMPATIBILITY 2026-09-14 (v1.8.4): Older bridges omit dispatch ownership.
    // Retire unknown when all supported production bridges report this field.
    @JsonKey(unknownEnumValue: QueuedPromptDispatchState.unknown)
    @Default(QueuedPromptDispatchState.unknown)
    QueuedPromptDispatchState dispatchState,

    /// User-visible prompt text. Null for an attachment-only prompt — never
    /// an empty string.
    required String? text,

    /// Bare slash-command name for a command send, without the leading `/`.
    /// Null for a plain prompt.
    required String? command,

    /// Number of file attachments carried by the prompt.
    @Default(0) int attachmentCount,

    /// Bridge acceptance time in milliseconds since the Unix epoch.
    required int createdAt,
  }) = _QueuedSessionPrompt;

  factory fromJson(Map<String, dynamic> json) => _$QueuedSessionPromptFromJson(json);
}

/// Response body for `POST /session/queued_prompts`.
@Freezed(fromJson: true, toJson: true)
sealed class QueuedPromptResponse with _$QueuedPromptResponse {
  const factory({
    required List<QueuedSessionPrompt> data,
  }) = _QueuedPromptResponse;

  factory fromJson(Map<String, dynamic> json) => _$QueuedPromptResponseFromJson(json);
}

/// Request body for `POST /session/prompt/cancel`.
@Freezed(fromJson: true, toJson: true)
sealed class CancelQueuedPromptRequest with _$CancelQueuedPromptRequest {
  const factory({
    required String sessionId,
    required String promptId,
  }) = _CancelQueuedPromptRequest;

  factory fromJson(Map<String, dynamic> json) => _$CancelQueuedPromptRequestFromJson(json);
}
