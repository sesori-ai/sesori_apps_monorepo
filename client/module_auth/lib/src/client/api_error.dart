import "package:freezed_annotation/freezed_annotation.dart";

part "api_error.freezed.dart";

part "api_error.g.dart";

@Freezed(fromJson: true, toStringOverride: false)
sealed class ApiError._() extends Error with _$ApiError {
  factory jsonParsing(String jsonString) = JsonParsingError;

  // ignore: no_slop_linter/prefer_specific_type
  factory dartHttpClient(Object innerError) = DartHttpClientError;

  factory generic() = GenericError;

  factory notAuthenticated() = NotAuthenticatedError;

  factory nonSuccessCode({
    required int errorCode,
    required String? rawErrorString,
  }) = NonSuccessCodeError;

  factory emptyResponse() = EmptyResponseError;

  /// Parsing payloads can contain transcripts; keep the data, not its log rendering.
  @override
  String toString() => switch (this) {
    JsonParsingError() => "ApiError.jsonParsing(response body omitted)",
    DartHttpClientError(:final innerError) => "ApiError.dartHttpClient(innerError: ${innerError.toString()})",
    GenericError() => "ApiError.generic()",
    NotAuthenticatedError() => "ApiError.notAuthenticated()",
    NonSuccessCodeError(:final errorCode, :final rawErrorString) =>
      "ApiError.nonSuccessCode(errorCode: $errorCode, rawErrorString: $rawErrorString)",
    EmptyResponseError() => "ApiError.emptyResponse()",
  };
}
