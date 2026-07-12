import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Flutter implementation of [OAuthDeviceDescriptorProvider].
///
/// Derives the auth-server `clientType` from [defaultTargetPlatform] and reads
/// the device name + OS version (device_info_plus) and app version
/// (package_info_plus).
///
/// Never throws: the auth-init request requires a device, so device/package
/// reads are wrapped and a failure degrades to a best-effort descriptor
/// (platform-default name, null version fields). Values are clamped to the auth
/// server's schema limits.
@LazySingleton(as: OAuthDeviceDescriptorProvider)
class FlutterOAuthDeviceDescriptorProvider implements OAuthDeviceDescriptorProvider {
  FlutterOAuthDeviceDescriptorProvider(DeviceInfoPlugin deviceInfo) : _deviceInfo = deviceInfo;

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
    TargetPlatform.iOS => AuthClientType.appIos,
    TargetPlatform.android => AuthClientType.appAndroid,
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.fuchsia => AuthClientType.app,
  };

  Future<DeviceInfo> _device({required AuthClientType clientType, required String? appVersion}) async {
    // Web has no native device-info channel and the mobile getters throw an
    // UnsupportedError there; skip them to avoid noisy stack traces.
    if (kIsWeb) {
      return _deviceInfoBuilder.build(
        clientType: clientType,
        detectedName: null,
        osVersion: null,
        appVersion: appVersion,
      );
    }
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          final info = await _deviceInfo.iosInfo;
          return _deviceInfoBuilder.build(
            clientType: clientType,
            detectedName: info.name,
            osVersion: "iOS ${info.systemVersion}",
            appVersion: appVersion,
          );
        case TargetPlatform.android:
          final info = await _deviceInfo.androidInfo;
          return _deviceInfoBuilder.build(
            clientType: clientType,
            detectedName: "${info.manufacturer} ${info.model}",
            osVersion: "Android ${info.version.release}",
            appVersion: appVersion,
          );
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return _deviceInfoBuilder.build(
            clientType: clientType,
            detectedName: null,
            osVersion: null,
            appVersion: appVersion,
          );
      }
    } catch (error, stackTrace) {
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
    } catch (error, stackTrace) {
      logw("Failed to read app version for the OAuth device descriptor", error, stackTrace);
      return null;
    }
  }
}
