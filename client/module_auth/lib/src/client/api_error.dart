import "package:freezed_annotation/freezed_annotation.dart";

part "api_error.freezed.dart";

part "api_error.g.dart";

@Freezed(fromJson: true)
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

  // @override
  // StackTrace? get stackTrace => super.stackTrace;
}
