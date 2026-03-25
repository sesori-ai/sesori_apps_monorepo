import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Startup diagnostics for the bridge.
///
/// Runs checks that help surface configuration or permission issues early,
/// before the user encounters them at runtime.
class BridgeDiagnostics {
  /// Runs all diagnostic checks and logs warnings for any issues found.
  ///
  /// Returns `true` if all checks passed, `false` if any warnings were logged.
  Future<bool> runAll() async {
    var allPassed = true;

    if (!await checkFilesystemAccess()) {
      allPassed = false;
    }

    return allPassed;
  }

  /// Checks that the bridge can list directories the user is likely to browse.
  ///
  /// On macOS, Full Disk Access must be granted to the terminal app for
  /// directories like `~/Desktop`, `~/Documents`, and `~/Downloads`.
  /// This check tests listing a few common paths and warns if any fail.
  Future<bool> checkFilesystemAccess() async {
    final homeDir = Platform.environment["HOME"] ?? Platform.environment["USERPROFILE"];
    if (homeDir == null) {
      Log.w("[diagnostics] Could not determine home directory — filesystem suggestions may not work.");
      return false;
    }

    final testPaths = [
      homeDir,
      "$homeDir/Desktop",
      "$homeDir/Documents",
      "$homeDir/Downloads",
    ];

    var allAccessible = true;

    for (final path in testPaths) {
      final dir = Directory(path);
      if (!dir.existsSync()) continue;

      try {
        dir.listSync(followLinks: false);
      } on FileSystemException {
        Log.w(
          "[diagnostics] Cannot list $path — the terminal may need Full Disk Access "
          "(System Settings → Privacy & Security → Full Disk Access).",
        );
        allAccessible = false;
      }
    }

    if (allAccessible) {
      Log.d("[diagnostics] Filesystem access check passed.");
    }

    return allAccessible;
  }
}
