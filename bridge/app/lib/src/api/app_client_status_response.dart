import "package:freezed_annotation/freezed_annotation.dart";

part "app_client_status_response.freezed.dart";
part "app_client_status_response.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class AppClientStatusResponse with _$AppClientStatusResponse {
  const factory AppClientStatusResponse({required bool registered}) = _AppClientStatusResponse;

  factory AppClientStatusResponse.fromJson(Map<String, dynamic> json) => _$AppClientStatusResponseFromJson(json);
}
