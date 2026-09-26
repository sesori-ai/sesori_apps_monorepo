import "package:freezed_annotation/freezed_annotation.dart";

part "set_session_auto_continuation_request.freezed.dart";
part "set_session_auto_continuation_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SetSessionAutoContinuationRequest with _$SetSessionAutoContinuationRequest {
  const factory({required String sessionId, required bool enabled}) = _SetSessionAutoContinuationRequest;

  factory fromJson(Map<String, dynamic> json) => _$SetSessionAutoContinuationRequestFromJson(json);
}
