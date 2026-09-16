import "dart:ffi";
import "dart:io";

import "package:flutter/foundation.dart" show kReleaseMode, visibleForTesting;
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

/// Failed packaged-helper validation; the original error remains available for
/// diagnostics without rendering potentially malformed manifest contents.
final class const DesktopBridgeBundleException({
  required final String bundlePath,
  required final Object innerError,
}) implements BridgeExecutableResolutionException {
  @override
  String get userMessage =>
      "The bundled bridge is missing or does not match this app. Restart Sesori after an update. "
      "If this persists, reinstall the matching desktop download.";

  @override
  String toString() =>
      "DesktopBridgeBundleException: invalid or mismatched helper bundle at "
      '"$bundlePath" (${innerError.runtimeType.toString()}). $userMessage';
}

@visibleForTesting
typedef DesktopBridgeManifestReader = String Function({required String manifestPath});

/// Release helpers are bound to the running GUI's immutable build identity.
/// Debug/profile builds retain the explicit override and repository layout.
/// Validation happens on every resolve, including after an on-disk Linux upgrade.
@LazySingleton(as: BridgeExecutablePathResolver)
class DesktopBridgeExecutablePathResolver.forTesting({
  required final Map<String, String> _environment,
  required final String _workingDirectory,
  required final String _resolvedExecutable,
  required final DesktopBundleOs _os,
  required final DesktopBundleArchitecture _architecture,
  required final bool _isReleaseMode,
  required final String? _compiledIdentityJson,
  required final DesktopBridgeExecutableExists _executableExists,
  required final DesktopBridgeManifestReader _readManifest,
}) implements BridgeExecutablePathResolver {
  new()
    : this.forTesting(
        environment: Platform.environment,
        workingDirectory: Directory.current.path,
        resolvedExecutable: Platform.resolvedExecutable,
        os: DesktopBundleOs.values.byName(Platform.operatingSystem),
        architecture: DesktopBundleArchitecture.fromAbi(abi: Abi.current()),
        isReleaseMode: kReleaseMode,
        compiledIdentityJson: const bool.hasEnvironment(DesktopBundleIdentity.defineName)
            ? const String.fromEnvironment(DesktopBundleIdentity.defineName)
            : null,
        executableExists: ({required String executablePath}) => File(executablePath).existsSync(),
        readManifest: ({required String manifestPath}) => File(manifestPath).readAsStringSync(),
      );

  @visibleForTesting
  this;

  static const String environmentVariable = "SESORI_DESKTOP_BRIDGE_PATH";

  @override
  String resolve() => _isReleaseMode ? _resolvePackaged() : _resolveDevelopment();

  String _resolveDevelopment() {
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

  String _resolvePackaged() {
    final String executableDirectory = path.dirname(_resolvedExecutable);
    final String bundlePath = _os == DesktopBundleOs.macos
        ? path.join(path.dirname(executableDirectory), "Helpers", "bridge")
        : path.join(executableDirectory, "bridge");
    final String manifestPath = _os == DesktopBundleOs.macos
        ? path.join(path.dirname(executableDirectory), "Resources", DesktopBundleIdentity.manifestName)
        : path.join(bundlePath, DesktopBundleIdentity.manifestName);
    try {
      final String? compiledIdentityJson = _compiledIdentityJson;
      if (compiledIdentityJson == null) {
        throw StateError("Release GUI is missing its compiled desktop bundle identity");
      }
      final DesktopBundleIdentity expected = DesktopBundleIdentity.decode(encoded: compiledIdentityJson);
      final DesktopBundleIdentity actual = DesktopBundleIdentity.decode(
        encoded: _readManifest(manifestPath: manifestPath),
      );
      if (actual != expected || expected.os != _os || expected.architecture != _architecture) {
        throw StateError(
          "Desktop bundle identity mismatch: GUI=${expected.encode()}, helper=${actual.encode()}, "
          "host=${_os.name}/${_architecture.name}",
        );
      }
      final String executablePath = path.join(
        bundlePath,
        "bin",
        _os == DesktopBundleOs.windows ? "bridge.exe" : "bridge",
      );
      if (!_executableExists(executablePath: executablePath)) {
        throw FileSystemException("Packaged bridge executable is missing", executablePath);
      }
      return executablePath;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        DesktopBridgeBundleException(bundlePath: bundlePath, innerError: error),
        stackTrace,
      );
    }
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
        _os == DesktopBundleOs.windows ? "bridge.exe" : "bridge",
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
