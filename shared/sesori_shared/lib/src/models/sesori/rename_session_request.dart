import "package:freezed_annotation/freezed_annotation.dart";

part "rename_session_request.freezed.dart";

part "rename_session_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class RenameSessionRequest with _$RenameSessionRequest {
  const factory RenameSessionRequest({
    required String title,
  }) = _RenameSessionRequest;

  factory RenameSessionRequest.fromJson(Map<String, dynamic> json) => _$RenameSessionRequestFromJson(json);
}
