import "package:freezed_annotation/freezed_annotation.dart";

part "create_session_request.freezed.dart";

part "create_session_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class CreateSessionRequest with _$CreateSessionRequest {
  const factory CreateSessionRequest({
    required String projectId,
    String? parentSessionId,
  }) = _CreateSessionRequest;

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) => _$CreateSessionRequestFromJson(json);
}
