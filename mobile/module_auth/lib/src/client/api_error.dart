import "package:freezed_annotation/freezed_annotation.dart";

part "api_error.freezed.dart";

part "api_error.g.dart";

@Freezed(fromJson: true)
sealed class ApiError extends Error with _$ApiError {
  ApiError._();

  factory ApiError.jsonParsing(String jsonString) = JsonParsingError;

  factory ApiError.dartHttpClient(Object innerError) = DartHttpClientError;

  factory ApiError.generic() = GenericError;

  factory ApiError.notAuthenticated() = NotAuthenticatedError;

  factory ApiError.nonSuccessCode({
    required int errorCode,
    required String? rawErrorString,
  }) = NonSuccessCodeError;

  factory ApiError.emptyResponse() = EmptyResponseError;

  // @override
  // StackTrace? get stackTrace => super.stackTrace;
}
