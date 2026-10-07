import "dart:io" show Directory, Platform;

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show normalizeProjectDirectory, resolveUserHomeDirectory;

/// Decides whether a project found by a catalog scan starts hidden.
///
/// Temporary directories and folders whose first entry below the user home
/// starts with `.` stay hidden; every other project is visible.
class DiscoveredProjectVisibilityCalculator() {
  final String? _userHomeDirectory = _resolveNormalizedUserHomeDirectory();
  final String _temporaryDirectory = normalizeProjectDirectory(directory: Directory.systemTemp.path);

  bool shouldHide({required String projectPath}) {
    final path = normalizeProjectDirectory(directory: projectPath);
    // Scans discover history; only Add/Open Project explicitly reveals these folders.
    for (final temporaryDirectory in ["/tmp", "/private/tmp", _temporaryDirectory]) {
      if (p.equals(temporaryDirectory, path) || p.isWithin(temporaryDirectory, path)) return true;
    }
    final userHomeDirectory = _userHomeDirectory;
    if (userHomeDirectory == null || !p.isWithin(userHomeDirectory, path)) return false;
    final relativeSegments = p.split(p.relative(path, from: userHomeDirectory));
    return relativeSegments.isNotEmpty && relativeSegments.first.startsWith(".");
  }

  static String? _resolveNormalizedUserHomeDirectory() {
    final userHomeDirectory = resolveUserHomeDirectory(environment: Platform.environment);
    return userHomeDirectory == null ? null : normalizeProjectDirectory(directory: userHomeDirectory);
  }
}
