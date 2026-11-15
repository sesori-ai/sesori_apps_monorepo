import "package:freezed_annotation/freezed_annotation.dart";

part "send_to_session_request.freezed.dart";
part "send_to_session_request.g.dart";

/// Request body for `POST /session/send-to-session`.
///
/// The bridge asks the source session's agent for a handoff summary, saves the
/// source's transcript for the target, then prompts the target with both. The
/// response arrives once the target has accepted that prompt, or with a
/// [SendToSessionErrorResponse].
@Freezed(fromJson: true, toJson: true)
sealed class SendToSessionRequest with _$SendToSessionRequest {
  const factory({
    required String sourceSessionId,
    required String targetSessionId,
  }) = _SendToSessionRequest;

  factory fromJson(Map<String, dynamic> json) => _$SendToSessionRequestFromJson(json);
}
