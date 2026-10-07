import "package:freezed_annotation/freezed_annotation.dart";

part "session_tool_output.freezed.dart";
part "session_tool_output.g.dart";

/// Request body for `POST /session/tool-output`: the stored tool part
/// [partId] of message [messageId], whose page carried it as a summary.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionToolOutputRequest with _$SessionToolOutputRequest {
  const factory({
    required String sessionId,
    required String messageId,
    required String partId,
  }) = _SessionToolOutputRequest;

  factory fromJson(Map<String, dynamic> json) => _$SessionToolOutputRequestFromJson(json);
}

/// The body of `POST /session/tool-output`: the output and error a summary
/// tool part withheld, each null when the tool reported none.
@Freezed(fromJson: true, toJson: true, copyWith: false)
sealed class SessionToolOutputResponse with _$SessionToolOutputResponse {
  const factory({
    required String? output,
    required String? error,
  }) = _SessionToolOutputResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionToolOutputResponseFromJson(json);
}
