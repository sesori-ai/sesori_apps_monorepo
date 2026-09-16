import "package:freezed_annotation/freezed_annotation.dart";

part "api_error.freezed.dart";

part "api_error.g.dart";

@Freezed(fromJson: true, toStringOverride: false)
sealed class ApiError._() extends Error with _$ApiError {
  factory jsonParsing({
    required String jsonString,
    // ignore: no_slop_linter/prefer_specific_type, Dart permits arbitrary thrown objects; decoded failures may have no local cause
    required Object? innerError,
  }) = JsonParsingError;

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
    JsonParsingError(:final innerError) =>
      "ApiError.jsonParsing(response body omitted${innerError == null ? '' : '; ${_parsingDiagnostic(error: innerError)}'})",
    DartHttpClientError(:final innerError) => "ApiError.dartHttpClient(innerError: ${innerError.toString()})",
    GenericError() => "ApiError.generic()",
    NotAuthenticatedError() => "ApiError.notAuthenticated()",
    NonSuccessCodeError(:final errorCode, :final rawErrorString) =>
      "ApiError.nonSuccessCode(errorCode: $errorCode, rawErrorString: $rawErrorString)",
    EmptyResponseError() => "ApiError.emptyResponse()",
  };
}

// ignore: no_slop_linter/prefer_specific_type, presentation of the original arbitrary thrown object
String _parsingDiagnostic({required Object error}) => switch (error) {
  FormatException(:final offset) => "FormatException; offset=${offset?.toString() ?? 'unknown'}",
  CheckedFromJsonException(:final className, :final key, :final innerError) =>
    "CheckedFromJsonException; class=$className; key=$key; innerType=${innerError.runtimeType.toString()}",
  TypeError() => error.toString(),
  _ => "Response DTO conversion failed; type=${error.runtimeType.toString()}",
};
