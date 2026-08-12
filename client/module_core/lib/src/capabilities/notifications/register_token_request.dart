import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "register_token_request.freezed.dart";
part "register_token_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class RegisterTokenRequest with _$RegisterTokenRequest {
  const factory RegisterTokenRequest({
    required String token,
    required DevicePlatform platform,
    // Must serialize as an absent key rather than an explicit null: the server
    // treats deviceId as optional, which accepts omission but 400s on null.
    // include_if_null: false in build.yaml is what produces that package-wide.
    required String? deviceId,
  }) = _RegisterTokenRequest;

  factory RegisterTokenRequest.fromJson(Map<String, dynamic> json) => _$RegisterTokenRequestFromJson(json);
}
