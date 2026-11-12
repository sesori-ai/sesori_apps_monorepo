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
    // The server uses it to remove this device's older FCM registration-token
    // rows, so the pre-FID token stops duplicating pushes.
    required String deviceId,
  }) = _RegisterFidRequest;

  factory fromJson(Map<String, dynamic> json) => _$RegisterFidRequestFromJson(json);
}
