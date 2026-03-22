import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "register_token_request.freezed.dart";
part "register_token_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class RegisterTokenRequest with _$RegisterTokenRequest {
  const factory RegisterTokenRequest({
    required String token,
    required DevicePlatform platform,
  }) = _RegisterTokenRequest;

  factory RegisterTokenRequest.fromJson(Map<String, dynamic> json) => _$RegisterTokenRequestFromJson(json);
}
