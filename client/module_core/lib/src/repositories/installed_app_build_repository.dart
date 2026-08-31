import "package:injectable/injectable.dart";

import "../api/installed_app_build_api.dart";
import "../logging/logging.dart";
import "models/installed_app_build.dart";

@lazySingleton
class InstalledAppBuildRepository({required final InstalledAppBuildApi _api}) {
  Future<InstalledAppBuild?> read() async {
    final rawBuildNumber = await _api.readBuildNumber();
    if (rawBuildNumber == null) return null;
    final buildNumber = int.tryParse(rawBuildNumber);
    if (buildNumber == null || buildNumber <= 0) {
      logw("Installed app build source returned an invalid build number: $rawBuildNumber");
      return null;
    }
    return InstalledAppBuild(buildNumber: buildNumber);
  }
}
