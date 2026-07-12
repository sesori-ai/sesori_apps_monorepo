import "package:sesori_shared/sesori_shared.dart";

/// The platform-derived descriptor sent at OAuth init: the auth-server
/// `clientType` for this build (e.g. "app_ios" / "app_android") plus the
/// structured [DeviceInfo] describing the device that started the sign-in.
class OAuthDeviceDescriptor {
  const OAuthDeviceDescriptor({required this.clientType, required this.device});

  final AuthClientType clientType;
  final DeviceInfo device;
}

/// Supplies the [OAuthDeviceDescriptor] for this device.
///
/// `module_auth` is pure Dart and cannot read Flutter/native device APIs, so
/// the app layer provides the implementation (mirrors the `SecureStorage`
/// platform interface). There is exactly one production implementation.
///
/// [describe] must never throw: the auth-init request requires a device, so the
/// implementation degrades to a best-effort descriptor (platform-default name,
/// null version fields) rather than failing the whole login.
abstract interface class OAuthDeviceDescriptorProvider {
  Future<OAuthDeviceDescriptor> describe();
}
