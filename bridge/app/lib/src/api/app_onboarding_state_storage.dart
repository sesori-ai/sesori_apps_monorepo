import "dart:io";

import "package:path/path.dart" as path;

import "../foundation/data_directory_hardening.dart";

String appOnboardingStateDirectoryPath({required String dataDirectory}) => path.join(dataDirectory, "app_onboarding");

/// Raw file boundary for opaque app-onboarding completion markers.
class AppOnboardingStateStorage({required final String _directoryPath}) {
  Future<bool> markerExists({required String key}) => Future.value(File(path.join(_directoryPath, key)).existsSync());

  Future<void> writeMarker({required String key}) async {
    final markerPath = path.join(_directoryPath, key);
    await writeRestrictedFile(filePath: markerPath, contents: "");
  }

  Future<void> clearAll() {
    final directory = Directory(_directoryPath);
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    return Future<void>.value();
  }
}
