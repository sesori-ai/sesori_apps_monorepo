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
  static const _deviceInfoBuilder = AuthDeviceInfoBuilder();

  @override
  Future<OAuthDeviceDescriptor> describe() async {
    final clientType = _clientType();
    final appVersion = await _appVersion();
    final device = await _device(clientType: clientType, appVersion: appVersion);
    return OAuthDeviceDescriptor(clientType: clientType, device: device);
  }

  AuthClientType _clientType() => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => AuthClientType.appMacos,
    TargetPlatform.windows => AuthClientType.appWindows,
    TargetPlatform.linux => AuthClientType.appLinux,
    // Unreachable in the desktop shell; kept exhaustive with the generic type.
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => AuthClientType.app,
  };

  Future<DeviceInfo> _device({required AuthClientType clientType, required String? appVersion}) async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.macOS:
          final info = await _deviceInfo.macOsInfo;
          return _deviceInfoBuilder.build(
            clientType: clientType,
            detectedName: info.computerName,
            osVersion: "macOS ${info.majorVersion}.${info.minorVersion}.${info.patchVersion}",
            appVersion: appVersion,
          );
        case TargetPlatform.windows:
          final info = await _deviceInfo.windowsInfo;
          return _deviceInfoBuilder.build(
            clientType: clientType,
            detectedName: info.computerName,
            osVersion: info.productName,
            appVersion: appVersion,
          );
        case TargetPlatform.linux:
          final info = await _deviceInfo.linuxInfo;
          return _deviceInfoBuilder.build(
            clientType: clientType,
            detectedName: Platform.localHostname,
            osVersion: info.prettyName,
            appVersion: appVersion,
          );
        case TargetPlatform.iOS:
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          return _deviceInfoBuilder.build(
            clientType: clientType,
            detectedName: null,
            osVersion: null,
            appVersion: appVersion,
          );
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to read device info for the OAuth device descriptor", error, stackTrace);
      return _deviceInfoBuilder.build(
        clientType: clientType,
        detectedName: null,
        osVersion: null,
        appVersion: appVersion,
      );
    }
  }

  Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } on Object catch (error, stackTrace) {
      logw("Failed to read app version for the OAuth device descriptor", error, stackTrace);
      return null;
    }
  }
}
