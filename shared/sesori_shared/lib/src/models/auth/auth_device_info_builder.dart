import "auth_client_type.dart";
import "device_info.dart";

/// Builds auth device descriptors within the auth-server schema limits.
class AuthDeviceInfoBuilder {
  const AuthDeviceInfoBuilder();

  static const int maxNameLength = 120;
  static const int maxVersionLength = 40;

  DeviceInfo build({
    required AuthClientType clientType,
    required String? detectedName,
    required String? osVersion,
    required String? appVersion,
  }) {
    return DeviceInfo(
      name: _normalize(value: detectedName, maxLength: maxNameLength) ?? _fallbackName(clientType),
      osVersion: _normalize(value: osVersion, maxLength: maxVersionLength),
      appVersion: _normalize(value: appVersion, maxLength: maxVersionLength),
    );
  }

  String _fallbackName(AuthClientType clientType) => switch (clientType) {
    AuthClientType.bridge ||
    AuthClientType.bridgeMacos ||
    AuthClientType.bridgeWindows ||
    AuthClientType.bridgeLinux => "Sesori Bridge",
    AuthClientType.appIos => "iPhone",
    AuthClientType.appAndroid => "Android device",
    AuthClientType.appMacos => "Mac",
    AuthClientType.appWindows => "Windows device",
    AuthClientType.appLinux => "Linux device",
    AuthClientType.app => "Device",
  };

  String? _normalize({required String? value, required int maxLength}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.length > maxLength ? trimmed.substring(0, maxLength).trim() : trimmed;
  }
}
