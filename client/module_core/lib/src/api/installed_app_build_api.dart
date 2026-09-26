import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/platform/installed_app_build_source.dart";

@lazySingleton
class InstalledAppBuildApi({required final InstalledAppBuildSource _source}) {
  Future<String?> readBuildNumber() => _source.readBuildNumber();

  Future<String> readVersion() => _source.readVersion();

  DevicePlatform get devicePlatform => _source.devicePlatform;
}
