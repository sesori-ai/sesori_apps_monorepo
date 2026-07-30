import "package:freezed_annotation/freezed_annotation.dart";

part "session_options_error_response.freezed.dart";
part "session_options_error_response.g.dart";

enum SessionOptionsErrorCode {
  cacheUnavailable,
  projectNotFound,
  refreshFailedRetained,
  refreshFailedUnavailable,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionOptionsErrorResponse with _$SessionOptionsErrorResponse {
  const factory SessionOptionsErrorResponse({
    @JsonKey(unknownEnumValue: SessionOptionsErrorCode.unknown) required SessionOptionsErrorCode code,
  }) = _SessionOptionsErrorResponse;

  factory SessionOptionsErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionOptionsErrorResponseFromJson(json);
}
