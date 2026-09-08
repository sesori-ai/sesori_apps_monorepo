import "dart:io" show Platform;

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../foundation/antigravity_identity.dart";
import "../foundation/antigravity_release.dart";

/// Pinned managed-install facts for Google's official Antigravity ACP pair.
///
/// Google's registry versions the package separately from the ACP server's
/// initialize identity. Managed version directories use the registry package
/// version, while [AntigravityRuntimeVersionValidator] validates the exact
/// server identity and release through ACP initialize before placement.
class const AntigravityRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _version = SemanticRuntimeVersion.parse(
    value: AntigravityRelease.registryPackageVersion,
  );

  /// A conservative per-command bound for listing and extracting the official
  /// archives. It matches the established managed-runtime archive policy and is
  /// deliberately not derived from host-specific measurements.
  static const Duration archiveCommandTimeout = Duration(minutes: 2);

  @override
  String get runtimeId => AntigravityIdentity.pluginId;

  @override
  String get displayName => AntigravityIdentity.displayName;

  @override
  String get installDocsUrl => "https://antigravity.google/docs/";

  @override
  String get pathExecutableName =>
      Platform.isWindows ? AntigravityRelease.windowsServerFileName : AntigravityRelease.posixServerFileName;

  @override
  String get binaryFileName => pathExecutableName;

  @override
  RuntimeVersion get minPathVersion => _version;

  @override
  RuntimeVersion get bundledVersion => _version;

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) {
    final artifact = AntigravityRelease.artifactFor(target: target);
    if (artifact == null) return null;
    return ArchiveRuntimeAsset(
      assetName: Uri.parse(artifact.archiveUrl).pathSegments.last,
      format: ArchiveFormat.zip,
      archiveCommandTimeout: archiveCommandTimeout,
      sha256: artifact.archiveSha256,
      archiveBinaryName: AntigravityRelease.serverFileName(target: target),
      layout: RuntimeArchiveLayout.packageDirectory,
    );
  }

  @override
  String downloadUrlFor({required RuntimeAsset asset}) {
    for (final byArchitecture in AntigravityRelease.artifacts.values) {
      for (final artifact in byArchitecture.values) {
        if (Uri.parse(artifact.archiveUrl).pathSegments.last == asset.assetName) return artifact.archiveUrl;
      }
    }
    throw ArgumentError.value(asset.assetName, "asset", "not an official Antigravity release archive");
  }

  /// Exact managed server path for [target], including cross-target tests where
  /// the process platform differs from the selected target.
  String managedServerPath({required String stateDirectory, required PlatformTarget target}) {
    return p.join(
      stateDirectory,
      runtimeId,
      bundledVersion.raw,
      AntigravityRelease.serverFileName(target: target),
    );
  }
}
