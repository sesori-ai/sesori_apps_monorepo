import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@visibleForTesting
typedef DesktopBundleManifestReader = String Function({required String manifestPath});

/// Compiled build defines plus the `desktop-bundle.json` installed beside the
/// running executable.
@LazySingleton(as: InstalledDesktopBundleSource)
class IoInstalledDesktopBundleSource.forTesting({
  required final String? _compiledIdentityJson,
  @override required final DesktopReleaseChannel channel,
  @override required final bool isAppImage,
  required final String _resolvedExecutable,
  required final DesktopBundleOs _os,
  required final DesktopBundleManifestReader _readManifest,
}) implements InstalledDesktopBundleSource {
  new()
    : this.forTesting(
        compiledIdentityJson: const bool.hasEnvironment(DesktopBundleIdentity.defineName)
            ? const String.fromEnvironment(DesktopBundleIdentity.defineName)
            : null,
        channel: DesktopReleaseChannel.values.byName(
          const String.fromEnvironment(DesktopReleaseChannel.defineName, defaultValue: "stable"),
        ),
        isAppImage: Platform.isLinux && (Platform.environment["APPIMAGE"]?.isNotEmpty ?? false),
        resolvedExecutable: Platform.resolvedExecutable,
        os: DesktopBundleOs.values.byName(Platform.operatingSystem),
        readManifest: ({required String manifestPath}) => File(manifestPath).readAsStringSync(),
      );

  @visibleForTesting
  this;

  @override
  DesktopBundleIdentity? get compiledIdentity => switch (_compiledIdentityJson) {
    null => null,
    final encoded => DesktopBundleIdentity.decode(encoded: encoded),
  };

  @override
  DesktopBundleIdentity readInstalledIdentity() {
    final String executableDirectory = path.dirname(_resolvedExecutable);
    final String manifestPath = _os == DesktopBundleOs.macos
        ? path.join(path.dirname(executableDirectory), "Resources", DesktopBundleIdentity.manifestName)
        : path.join(executableDirectory, "bridge", DesktopBundleIdentity.manifestName);
    return DesktopBundleIdentity.decode(encoded: _readManifest(manifestPath: manifestPath));
  }
}
