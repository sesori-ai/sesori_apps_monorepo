import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Development bridge-path policy for the desktop shell.
///
/// An explicit `SESORI_DESKTOP_BRIDGE_PATH` wins. Otherwise `flutter run` from
/// `client/desktop` resolves the host bundle produced by
/// `bridge/app/make build-host`. Packaged-layout resolution belongs to the
/// distribution plan and will replace this repository-relative default.
@LazySingleton(as: BridgeExecutablePathResolver)
class DesktopBridgeExecutablePathResolver.forTesting({
  required final Map<String, String> _environment,
  required final String _workingDirectory,
  required final bool _isWindows,
}) implements BridgeExecutablePathResolver {
  new()
    : this.forTesting(
        environment: Platform.environment,
        workingDirectory: Directory.current.path,
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

    return path.normalize(
      path.join(
        _workingDirectory,
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
}
