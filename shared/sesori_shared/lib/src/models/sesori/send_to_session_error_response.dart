import "package:freezed_annotation/freezed_annotation.dart";

part "send_to_session_error_response.freezed.dart";
part "send_to_session_error_response.g.dart";

/// Why `POST /session/send-to-session` did not send.
enum SendToSessionErrorCode() {
  /// The source and the target are the same session.
  sameSession,
  sourceArchived,
  targetArchived,

  /// The source is a child session; only root sessions can be sent.
  sourceNotRoot,

  /// The source is running or retrying. Nothing was sent; the user can stop
  /// it and send again.
  sourceBusy,

  /// The source is waiting for the user to answer a question or permission.
  sourceAwaitingInput,

  /// The source's harness did not accept the summary request.
  sourceUnavailable,

  /// The source has no messages, so there is nothing to hand off.
  sourceEmpty,

  /// The source was stopped while writing the summary.
  summaryStopped,

  /// The source's turn ended with a session error while writing the summary.
  summaryFailed,

  /// The source did not finish the summary within the bridge's wait.
  summaryTimedOut,

  /// The source's turn ended without any summary text.
  summaryMissing,

  /// The source's transcript could not be saved for the target.
  transcriptUnavailable,

  /// The target did not accept the handoff prompt.
  targetRefused,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class SendToSessionErrorResponse with _$SendToSessionErrorResponse {
  const factory({
    @JsonKey(unknownEnumValue: SendToSessionErrorCode.unknown) required SendToSessionErrorCode code,

    /// The harness's own explanation, written for the user and safe to show,
    /// when it refused the target prompt for a reason it explained. Null for
    /// every other failure.
    required String? message,
  }) = _SendToSessionErrorResponse;

  factory fromJson(Map<String, dynamic> json) => _$SendToSessionErrorResponseFromJson(json);
}
