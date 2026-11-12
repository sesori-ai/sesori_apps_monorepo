import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "register_fid_request.freezed.dart";
part "register_fid_request.g.dart";

/// Registers this installation's Firebase Installation ID for push delivery.
@Freezed(fromJson: true, toJson: true)
sealed class RegisterFidRequest with _$RegisterFidRequest {
  const factory({
    required String fid,
    required DevicePlatform platform,
    // With a deviceId the server also removes this device's older FCM
    // registration-token rows, so the pre-FID token stops duplicating pushes.
    // Must serialize as an absent key rather than an explicit null: the server
    // treats deviceId as optional, which accepts omission but 400s on null.
    // include_if_null: false in build.yaml is what produces that package-wide.
    required String? deviceId,
  }) = _RegisterFidRequest;

  factory fromJson(Map<String, dynamic> json) => _$RegisterFidRequestFromJson(json);
}
