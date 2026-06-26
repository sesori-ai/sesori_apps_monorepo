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

  static const _maxNameLength = 120;
  static const _maxVersionLength = 40;

  @override
  Future<OAuthDeviceDescriptor> describe() async {
    final appVersion = await _appVersion();
    final device = await _device(appVersion: appVersion);
    return OAuthDeviceDescriptor(clientType: _clientType(), device: device);
  }

  String _clientType() => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => "app_ios",
        TargetPlatform.android => "app_android",
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux ||
        TargetPlatform.fuchsia =>
          "app",
      };

  Future<DeviceInfo> _device({required String? appVersion}) async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          final info = await _deviceInfo.iosInfo;
          return DeviceInfo(
            name: _clamp(info.name, _maxNameLength) ?? _fallbackName(),
            osVersion: _clamp("iOS ${info.systemVersion}", _maxVersionLength),
            appVersion: appVersion,
          );
        case TargetPlatform.android:
          final info = await _deviceInfo.androidInfo;
          return DeviceInfo(
            name: _clamp("${info.manufacturer} ${info.model}", _maxNameLength) ?? _fallbackName(),
            osVersion: _clamp("Android ${info.version.release}", _maxVersionLength),
            appVersion: appVersion,
          );
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return DeviceInfo(name: _fallbackName(), osVersion: null, appVersion: appVersion);
      }
    } catch (error, stackTrace) {
      logw("Failed to read device info for the OAuth device descriptor", error, stackTrace);
      return DeviceInfo(name: _fallbackName(), osVersion: null, appVersion: appVersion);
    }
  }

  Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return _clamp(info.version, _maxVersionLength);
    } catch (error, stackTrace) {
      logw("Failed to read app version for the OAuth device descriptor", error, stackTrace);
      return null;
    }
  }

  String _fallbackName() => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => "iPhone",
        TargetPlatform.android => "Android device",
        TargetPlatform.macOS => "Mac",
        TargetPlatform.windows => "Windows device",
        TargetPlatform.linux => "Linux device",
        TargetPlatform.fuchsia => "Device",
      };

  String? _clamp(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > maxLength ? trimmed.substring(0, maxLength).trim() : trimmed;
  }
}
