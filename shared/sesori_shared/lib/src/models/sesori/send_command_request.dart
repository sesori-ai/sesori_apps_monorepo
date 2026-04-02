import "package:freezed_annotation/freezed_annotation.dart";

part "send_command_request.freezed.dart";

part "send_command_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SendCommandRequest with _$SendCommandRequest {
  const factory SendCommandRequest({
    required String sessionId,
    required String command,
    required String arguments,
  }) = _SendCommandRequest;

  factory SendCommandRequest.fromJson(Map<String, dynamic> json) => _$SendCommandRequestFromJson(json);
}
