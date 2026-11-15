import "package:freezed_annotation/freezed_annotation.dart";

import "send_prompt_request.dart";
import "session_variant.dart";

part "rewind_session_request.freezed.dart";
part "rewind_session_request.g.dart";

/// Request body for `POST /session/rewind`: edit and resend.
///
/// Removes [messageId], a user message that opens a turn, and every later
/// message from the session's conversation, then sends [parts] as its next
/// prompt. Files are never touched. Refusals answer `SessionBranchErrorResponse`.
@Freezed(fromJson: true, toJson: true)
sealed class RewindSessionRequest with _$RewindSessionRequest {
  const factory({
    required String sessionId,
    required String messageId,

    /// Client-generated identity of the edited prompt, stable across retries.
    /// A retry of an accepted edit succeeds without rewinding again.
    required String promptId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,

    /// Whether this and later turns run in the backend's fast mode.
    required bool fastMode,
  }) = _RewindSessionRequest;

  factory fromJson(Map<String, dynamic> json) => _$RewindSessionRequestFromJson(json);
}
