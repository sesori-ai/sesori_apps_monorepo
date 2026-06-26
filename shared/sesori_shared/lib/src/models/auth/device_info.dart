import "package:freezed_annotation/freezed_annotation.dart";

part "device_info.freezed.dart";
part "device_info.g.dart";

/// Optional structured descriptor sent at OAuth init so the auth-server
/// confirmation page can describe the device that started the sign-in.
///
/// [name] is a human-recognizable machine/device name (a recognition aid only,
/// untrusted and HTML-escaped server-side — clients must NOT pre-escape it).
/// Type + OS family are derived server-side from `clientType`, so keep those out
/// of [name]. [osVersion]/[appVersion] are cosmetic; null values are omitted
/// from the wire payload (json_serializable `include_if_null: false` default).
@Freezed(fromJson: true, toJson: true)
sealed class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    required String name,
    required String? osVersion,
    required String? appVersion,
  }) = _DeviceInfo;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => _$DeviceInfoFromJson(json);
}
