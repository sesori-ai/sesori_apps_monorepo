import "package:freezed_annotation/freezed_annotation.dart";

import "api_error.dart";

part "api_response.freezed.dart";

@Freezed()
sealed class ApiResponse<T> with _$ApiResponse<T> {
  ApiResponse._();

  factory ApiResponse.success(T data) = SuccessResponse;

  factory ApiResponse.error(ApiError error) = ErrorResponse;
}
