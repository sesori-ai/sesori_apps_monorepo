import "package:freezed_annotation/freezed_annotation.dart";

part "session_options_error_response.freezed.dart";
part "session_options_error_response.g.dart";

enum SessionOptionsErrorCode() {
  cacheUnavailable,
  projectNotFound,
  authenticationRequired,
  refreshFailedRetained,
  refreshFailedUnavailable,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionOptionsErrorResponse with _$SessionOptionsErrorResponse {
  const factory({
    @JsonKey(unknownEnumValue: SessionOptionsErrorCode.unknown) required SessionOptionsErrorCode code,

    /// Privacy-safe, plugin-owned guidance for [SessionOptionsErrorCode.authenticationRequired].
    /// Null for every other code and for peers that do not provide guidance.
    required String? actionHint,
  }) = _SessionOptionsErrorResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionOptionsErrorResponseFromJson(json);
}
