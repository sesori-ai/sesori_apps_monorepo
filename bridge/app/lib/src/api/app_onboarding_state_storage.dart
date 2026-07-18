import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show sesoriDataDirectory;

String appOnboardingStateDirectoryPath() => path.join(sesoriDataDirectory(), "app_onboarding");

/// Raw file boundary for opaque app-onboarding completion markers.
class AppOnboardingStateStorage {
  AppOnboardingStateStorage({required String directoryPath}) : _directoryPath = directoryPath;

  final String _directoryPath;

  Future<bool> markerExists({required String key}) => Future.value(File(path.join(_directoryPath, key)).existsSync());

  Future<void> writeMarker({required String key}) async {
    final directory = Directory(_directoryPath);
    await directory.create(recursive: true);
    if (!Platform.isWindows) {
      await _setUnixMode(targetPath: directory.path, mode: "700");
    }

    final markerPath = path.join(_directoryPath, key);
    if (Platform.isWindows) {
      await File(markerPath).writeAsString("");
      return;
    }

    final temporaryMarker = File("$markerPath.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp");
    try {
      await temporaryMarker.writeAsString("");
      await _setUnixMode(targetPath: temporaryMarker.path, mode: "600");
      await temporaryMarker.rename(markerPath);
    } finally {
      if (temporaryMarker.existsSync()) {
        temporaryMarker.deleteSync();
      }
    }
  }

  Future<void> clearAll() {
    final directory = Directory(_directoryPath);
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    return Future<void>.value();
  }

  Future<void> _setUnixMode({required String targetPath, required String mode}) async {
    final result = await Process.run("chmod", [mode, targetPath]);
    if (result.exitCode != 0) {
      throw FileSystemException("Failed to set mode $mode", targetPath);
    }
  }
}
