import "dart:convert";
import "dart:ffi";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

part "desktop_bundle_identity.freezed.dart";
part "desktop_bundle_identity.g.dart";

/// Supported installed desktop layouts, not client/bridge transport platforms.
enum DesktopBundleOs() {
  macos,
  windows,
  linux,
}

enum DesktopBundleArchitecture() {
  x64,
  arm64;

  static DesktopBundleArchitecture fromAbi({required Abi abi}) => switch (abi) {
    Abi.macosX64 || Abi.windowsX64 || Abi.linuxX64 => x64,
    Abi.macosArm64 || Abi.windowsArm64 || Abi.linuxArm64 => arm64,
    _ => throw UnsupportedError("Unsupported desktop ABI: ${abi.toString()}"),
  };
}

/// Immutable build metadata shared by the compiled GUI and its staged helper.
/// This is neither a wire contract nor a mutable application data file.
@Freezed(fromJson: true, toJson: true)
sealed class const DesktopBundleIdentity._() with _$DesktopBundleIdentity {
  const factory({
    required String version,
    required int buildNumber,
    required String sourceSha,
    required DesktopBundleOs os,
    required DesktopBundleArchitecture architecture,
  }) = _DesktopBundleIdentity;

  factory fromJson(Map<String, dynamic> json) => _$DesktopBundleIdentityFromJson(json);

  factory decode({required String encoded}) => DesktopBundleIdentity.fromJson(jsonDecodeMap(encoded));

  static const String manifestName = "desktop-bundle.json";
  static const String defineName = "SESORI_DESKTOP_BUNDLE_IDENTITY";

  String encode() => jsonEncode(toJson());
}
