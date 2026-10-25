import "dart:io";

import "package:injectable/injectable.dart";

/// Tells a relaunched desktop to wait for the exiting one to release the
/// primary lock instead of activating it.
const String desktopAfterUpdateLaunchArgument = "--after-update";

/// Layer-1 process boundary that starts the package-installed desktop again.
@lazySingleton
class DesktopRelaunchApi() {
  static const String _packageLauncherPath = "/usr/bin/sesori-desktop";

  /// Starts the launcher the DEB and RPM install, detached so it outlives this process.
  Future<void> relaunchInstalledPackage() async {
    await Process.start(
      _packageLauncherPath,
      const <String>[desktopAfterUpdateLaunchArgument],
      mode: ProcessStartMode.detached,
    );
  }
}
