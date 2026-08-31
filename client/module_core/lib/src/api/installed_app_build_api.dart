import "package:injectable/injectable.dart";

import "../foundation/platform/installed_app_build_source.dart";

@lazySingleton
class InstalledAppBuildApi({required final InstalledAppBuildSource _source}) {
  Future<String?> readBuildNumber() => _source.readBuildNumber();
}
