import "package:freezed_annotation/freezed_annotation.dart";

import "auth_user.dart";

part "auth_me_response.freezed.dart";
part "auth_me_response.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class AuthMeResponse with _$AuthMeResponse {
  const factory AuthMeResponse({
    required AuthUser user,
  }) = _AuthMeResponse;

  factory AuthMeResponse.fromJson(Map<String, dynamic> json) => _$AuthMeResponseFromJson(json);
}
