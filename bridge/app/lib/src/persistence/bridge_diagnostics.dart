import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Startup diagnostics for the bridge.
///
/// Runs checks that help surface configuration or permission issues early,
/// before the user encounters them at runtime.
class BridgeDiagnostics({required final bool _isSupervised}) {
  /// Runs all diagnostic checks and logs warnings for any issues found.
  ///
  /// Returns `true` if all checks passed, `false` if any warnings were logged.
  Future<bool> runAll() async {
    try {
      final (hasFileSystemAccess, hasGitAvailable) = await (checkFilesystemAccess(), checkGitAvailable()).wait;
      return hasFileSystemAccess && hasGitAvailable;
    } on Object catch (error, stackTrace) {
      Log.w("Unexpected error during diagnostics: $error\n$stackTrace");
      return false;
    }
  }

  Future<bool> checkGitAvailable() async {
    try {
      final result = await Process.run("git", ["--version"]);
      if (result.exitCode != 0) {
        Log.w("git is not available - worktree creation will be skipped.");
        return false;
      }
      Log.d("Git available: ${result.stdout.toString().trim()}");
      return true;
    } on Object {
      Log.w("git is not installed - worktree creation will be skipped.");
      return false;
    }
  }

  String get _accessSubject => _isSupervised
      ? "the Sesori desktop app or its supervised bridge helper"
      : "the application or terminal running the bridge";

  /// Checks that the bridge can list directories the user is likely to browse.
  ///
  /// On macOS, Full Disk Access must be granted to the application or terminal
  /// process that is actually running the bridge for directories like
  /// `~/Desktop`, `~/Documents`, and `~/Downloads`. This check tests listing a
  /// few common paths and warns if any fail.
  Future<bool> checkFilesystemAccess() async {
    final homeDir = resolveUserHomeDirectory(environment: Platform.environment);
    if (homeDir == null) {
      Log.w("Could not determine home directory — filesystem suggestions may not work.");
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
          "Cannot list $path — $_accessSubject may need Full Disk Access "
          "(System Settings → Privacy & Security → Full Disk Access).",
        );
        allAccessible = false;
      }
    }

    if (allAccessible) {
      Log.d("Filesystem access check passed.");
    }

    return allAccessible;
  }
}
