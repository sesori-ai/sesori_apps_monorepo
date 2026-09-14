import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@visibleForTesting
typedef DesktopBridgeExecutableExists = bool Function({required String executablePath});

/// Raised when the desktop's resolved bridge helper has not been built or the
/// explicit helper override points to a missing file.
final class const DesktopBridgeExecutableNotFoundException({
  required final String executablePath,
  required final bool usesConfiguredPath,
}) implements Exception {
  @override
  String toString() {
    if (usesConfiguredPath) {
      return "DesktopBridgeExecutableNotFoundException: "
          "${DesktopBridgeExecutablePathResolver.environmentVariable} points to a missing desktop bridge "
          'executable at "$executablePath". Update it to an existing helper before starting the desktop app.';
    }
    return "DesktopBridgeExecutableNotFoundException: development desktop bridge has not been built at "
        '"$executablePath". From the repository root, run `cd bridge/app && make build-host`, then restart the '
        "desktop app.";
  }
}

/// Development bridge-path policy for the desktop shell.
///
/// An explicit `SESORI_DESKTOP_BRIDGE_PATH` wins. Otherwise the repository
/// host bundle produced by `cd bridge/app && make build-host` is resolved from the
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
  required final DesktopBridgeExecutableExists _executableExists,
}) implements BridgeExecutablePathResolver {
  new()
    : this.forTesting(
        environment: Platform.environment,
        workingDirectory: Directory.current.path,
        resolvedExecutable: Platform.resolvedExecutable,
        isWindows: Platform.isWindows,
        executableExists: ({required String executablePath}) => File(executablePath).existsSync(),
      );

  @visibleForTesting
  this;

  static const String environmentVariable = "SESORI_DESKTOP_BRIDGE_PATH";

  @override
  String resolve() {
    final String? configuredPath = _environment[environmentVariable]?.trim();
    final bool usesConfiguredPath;
    final String executablePath;
    if (configuredPath != null && configuredPath.isNotEmpty) {
      usesConfiguredPath = true;
      executablePath = path.normalize(
        path.isAbsolute(configuredPath) ? configuredPath : path.join(_workingDirectory, configuredPath),
      );
    } else {
      usesConfiguredPath = false;
      final String? desktopPackageDirectory = _findDesktopPackageDirectory(startPath: _workingDirectory);
      final String? executablePackageDirectory = _findDesktopPackageDirectory(startPath: _resolvedExecutable);
      executablePath = _bridgePath(
        desktopPackageDirectory: desktopPackageDirectory ?? executablePackageDirectory ?? _workingDirectory,
      );
    }

    if (!_executableExists(executablePath: executablePath)) {
      throw DesktopBridgeExecutableNotFoundException(
        executablePath: executablePath,
        usesConfiguredPath: usesConfiguredPath,
      );
    }
    return executablePath;
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
