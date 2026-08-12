import "package:freezed_annotation/freezed_annotation.dart";

part "success_empty_response.freezed.dart";

part "success_empty_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SuccessEmptyResponse with _$SuccessEmptyResponse {
  const factory() = _SuccessEmptyResponse;

  factory fromJson(Map<String, dynamic> json) => _$SuccessEmptyResponseFromJson(json);
}
