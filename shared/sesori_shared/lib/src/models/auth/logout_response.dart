import "package:freezed_annotation/freezed_annotation.dart";

part "logout_response.freezed.dart";
part "logout_response.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class LogoutResponse with _$LogoutResponse {
  const factory({
    required bool success,
  }) = _LogoutResponse;

  factory fromJson(Map<String, dynamic> json) => _$LogoutResponseFromJson(json);
}
