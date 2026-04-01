import "package:freezed_annotation/freezed_annotation.dart";

part "success_empty_response.freezed.dart";

part "success_empty_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SuccessEmptyResponse with _$SuccessEmptyResponse {
  const factory SuccessEmptyResponse() = _SuccessEmptyResponse;

  factory SuccessEmptyResponse.fromJson(Map<String, dynamic> json) => _$SuccessEmptyResponseFromJson(json);
}
