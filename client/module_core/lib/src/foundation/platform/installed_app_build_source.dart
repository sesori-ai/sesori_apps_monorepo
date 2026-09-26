import "package:sesori_shared/sesori_shared.dart";

abstract interface class InstalledAppBuildSource() {
  Future<String?> readBuildNumber();

  /// The installed version name, such as `1.6.0`. Throws when the platform
  /// cannot report it.
  Future<String> readVersion();

  DevicePlatform get devicePlatform;
}
