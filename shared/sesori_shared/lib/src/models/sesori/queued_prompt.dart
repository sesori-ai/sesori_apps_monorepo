import "package:freezed_annotation/freezed_annotation.dart";

part "queued_prompt.freezed.dart";

part "queued_prompt.g.dart";

/// One prompt the bridge has accepted for a session but not yet dispatched to
/// the backend.
///
/// The bridge owns this state: clients render it, cancel it, and drop their
/// local copy once it appears. When the prompt dispatches, the transcript's
/// user message carries the same [id] as its `promptId` so clients can
/// transform the queued bubble into the sent message without a remove/re-add.
@Freezed(fromJson: true, toJson: true)
sealed class QueuedSessionPrompt with _$QueuedSessionPrompt {
  const factory({
    /// The prompt id: client-supplied `SendPromptRequest.promptId`, or a
    /// bridge-generated fallback for clients that predate it.
    required String id,

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
