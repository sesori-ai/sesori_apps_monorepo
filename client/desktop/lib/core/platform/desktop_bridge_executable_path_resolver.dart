import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Development bridge-path policy for the desktop shell.
///
/// An explicit `SESORI_DESKTOP_BRIDGE_PATH` wins. Otherwise the repository
/// host bundle produced by `bridge/app/make build-host` is resolved from the
/// desktop package location. The executable location is used as a fallback
/// because launchd starts a LaunchAgent with `/` as its working directory.
/// Packaged-layout resolution belongs to the distribution plan and will
/// replace this repository-relative default.
@LazySingleton(as: BridgeExecutablePathResolver)
class DesktopBridgeExecutablePathResolver.forTesting({
  required final Map<String, String> _environment,
  required final String _workingDirectory,
  required final String _resolvedExecutable,
  required final bool _isWindows,
}) implements BridgeExecutablePathResolver {
  new()
    : this.forTesting(
        environment: Platform.environment,
        workingDirectory: Directory.current.path,
        resolvedExecutable: Platform.resolvedExecutable,
        isWindows: Platform.isWindows,
      );

  @visibleForTesting
  this;

  static const String environmentVariable = "SESORI_DESKTOP_BRIDGE_PATH";

  @override
  String resolve() {
    final String? configuredPath = _environment[environmentVariable]?.trim();
    if (configuredPath != null && configuredPath.isNotEmpty) {
      return path.normalize(
        path.isAbsolute(configuredPath) ? configuredPath : path.join(_workingDirectory, configuredPath),
      );
    }

    final String? desktopPackageDirectory = _findDesktopPackageDirectory(startPath: _workingDirectory);
    final String? executablePackageDirectory = _findDesktopPackageDirectory(startPath: _resolvedExecutable);
    return _bridgePath(
      desktopPackageDirectory: desktopPackageDirectory ?? executablePackageDirectory ?? _workingDirectory,
    );
  }

  String _bridgePath({required String desktopPackageDirectory}) {
    return path.normalize(
      path.join(
        desktopPackageDirectory,
        "..",
        "..",
        "bridge",
        "app",
        "build",
        "cli",
        "bundle",
        "bin",
        _isWindows ? "bridge.exe" : "bridge",
      ),
    );
  }

  /// Finds the repository's desktop package by path shape rather than probing
  /// the filesystem. A missing helper should still produce the expected
  /// repository path in its startup error, and this keeps resolution usable in
  /// tests before a host bundle has been built.
  String? _findDesktopPackageDirectory({required String startPath}) {
    String current = path.normalize(startPath);
    while (true) {
      if (path.basename(current) == "desktop" && path.basename(path.dirname(current)) == "client") {
        return current;
      }
      final String parent = path.dirname(current);
      if (parent == current) {
        return null;
      }
      current = parent;
    }
  }
}
