import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "package_info_client.dart";

@LazySingleton(as: InstalledAppBuildSource)
class PackageInfoInstalledAppBuildSource({
  required final PackageInfoClient _packageInfoClient,
}) implements InstalledAppBuildSource {
  @override
  Future<String?> readBuildNumber() async {
    try {
      return (await _packageInfoClient.read()).buildNumber;
    } on Object catch (error, stackTrace) {
      logw("Failed to read the installed app build number", error, stackTrace);
      return null;
    }
  }
}
