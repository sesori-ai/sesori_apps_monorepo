import "dart:io";

import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Desktop implementation of [OAuthDeviceDescriptorProvider].
///
/// Sends the desktop-specific auth-server `clientType` (`app_macos` /
/// `app_windows` / `app_linux`) so the sign-in confirmation interstitial
/// labels the device "macOS desktop" / "Windows desktop" / "Linux desktop"
/// rather than "mobile app", plus a recognizable machine name.
///
/// Never throws: the auth-init request requires a device, so device/package
/// reads are wrapped and a failure degrades to a best-effort descriptor
/// (platform-default name, null version fields). Values are clamped to the
/// auth server's schema limits.
@LazySingleton(as: OAuthDeviceDescriptorProvider)
class DesktopOAuthDeviceDescriptorProvider implements OAuthDeviceDescriptorProvider {
  DesktopOAuthDeviceDescriptorProvider(DeviceInfoPlugin deviceInfo) : _deviceInfo = deviceInfo;

  final DeviceInfoPlugin _deviceInfo;

  static const _maxNameLength = 120;
  static const _maxVersionLength = 40;

  @override
  Future<OAuthDeviceDescriptor> describe() async {
    final appVersion = await _appVersion();
    final device = await _device(appVersion: appVersion);
    return OAuthDeviceDescriptor(clientType: _clientType(), device: device);
  }

  String _clientType() => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => "app_macos",
    TargetPlatform.windows => "app_windows",
    TargetPlatform.linux => "app_linux",
    // Unreachable in the desktop shell; kept exhaustive with the generic type.
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => "app",
  };

  Future<DeviceInfo> _device({required String? appVersion}) async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
          final info = await _deviceInfo.macOsInfo;
          return DeviceInfo(
            name: _clamp(value: info.computerName, maxLength: _maxNameLength) ?? _fallbackName(),
            osVersion: _clamp(
              value: "macOS ${info.majorVersion}.${info.minorVersion}.${info.patchVersion}",
              maxLength: _maxVersionLength,
            ),
            appVersion: appVersion,
          );
        case TargetPlatform.windows:
          final info = await _deviceInfo.windowsInfo;
          return DeviceInfo(
            name: _clamp(value: info.computerName, maxLength: _maxNameLength) ?? _fallbackName(),
            osVersion: _clamp(value: info.productName, maxLength: _maxVersionLength),
            appVersion: appVersion,
          );
        case TargetPlatform.linux:
          final info = await _deviceInfo.linuxInfo;
          return DeviceInfo(
            name: _clamp(value: Platform.localHostname, maxLength: _maxNameLength) ?? _fallbackName(),
            osVersion: _clamp(value: info.prettyName, maxLength: _maxVersionLength),
            appVersion: appVersion,
          );
        case TargetPlatform.iOS:
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          return DeviceInfo(name: _fallbackName(), osVersion: null, appVersion: appVersion);
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to read device info for the OAuth device descriptor", error, stackTrace);
      return DeviceInfo(name: _fallbackName(), osVersion: null, appVersion: appVersion);
    }
  }

  Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return _clamp(value: info.version, maxLength: _maxVersionLength);
    } on Object catch (error, stackTrace) {
      logw("Failed to read app version for the OAuth device descriptor", error, stackTrace);
      return null;
    }
  }

  String _fallbackName() => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => "Mac",
    TargetPlatform.windows => "Windows device",
    TargetPlatform.linux => "Linux device",
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => "Device",
  };

  String? _clamp({required String value, required int maxLength}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > maxLength ? trimmed.substring(0, maxLength).trim() : trimmed;
  }
}
