import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

/// Pinned facts about the OpenCode runtime the bridge can install and gate, as a
/// [RuntimeManifest] consumed by the shared `ManagedRuntimeProvisionService`.
///
/// Two version constants drive provisioning:
/// - [minPathVersion] gates a *pre-installed* (PATH) OpenCode: at or above it,
///   the bridge uses the user's own install; below it, startup is blocked until
///   that install is updated. Managed installation is permitted only when PATH
///   has no OpenCode. Never downgrade a newer install: OpenCode migrates its DB.
/// - [bundledVersion] is the exact version the managed runtime downloads.
///
/// ## Bumping the bundled runtime
/// 1. Resolve the stable `@opencode/cli` npm version and matching upstream tag.
/// 2. Download all six `@opencode/cli-<target>` tarballs and verify npm integrity.
/// 3. Update [targetVersion] and [_assets] with SHA-256 hashes of those bytes;
///    confirm each entrypoint is `package/bin/opencode[.exe]`.
/// 4. Regenerate v2 REST models and audit/regenerate its SSE manifest at that tag.
///    Preserve [_minPathVersion] unless a separate compatibility change is approved.
class const OpenCodeRuntimeManifest() extends RuntimeManifest {
  /// Minimum pre-installed OpenCode version the bridge will use as-is.
  /// Conservative on purpose: prefer the user's own compatible install and
  /// only download the managed runtime for genuinely old installs.
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "1.14.0");

  /// The latest stable OpenCode release targeted by this plugin.
  static const String targetVersion = "2.1.4";

  /// The exact OpenCode version the managed runtime installs.
  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  /// All six npm assets are gzip tarballs containing one self-contained binary
  /// under `package/bin/`. Installation normalizes it to [binaryFileName].
  /// Linux uses the standard, non-musl builds.
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-darwin-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "daa2fe04f27885090dccaeed9e0d6514bc80a7849ccb0a9d94521b383851bfa5",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-darwin-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "58677f9cab0cfbaf340a7eebf434035183bf1da6fb6a3a4134444a3206d6b3fe",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-linux-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "e9acb4e23a9ac432139693aa166455a6add8946533394cbe083459a48e788861",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-linux-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "ce05abe2dce1041391c8ec8cdb8da066f640fd471e72ac846dcb089c441e11e1",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-windows-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "899b17c989af0392b6f453a1d220054eaf6499a5e482a13fff557c366a7bf6d7",
        archiveBinaryName: "package/bin/opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-windows-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "cdd10a40552893d72e5a6920d63cebff1e9c056a2d28f77cf617267d453720c1",
        archiveBinaryName: "package/bin/opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
  };

  @override
  String get runtimeId => "opencode";

  @override
  String get displayName => "OpenCode";

  @override
  String get installDocsUrl => "https://opencode.ai/docs#install";

  @override
  String get pathExecutableName => "opencode";

  /// The canonical installed executable file name.
  @override
  String get binaryFileName => Platform.isWindows ? "opencode.exe" : "opencode";

  @override
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  /// The pinned asset for [target], or `null` when the platform is unsupported.
  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) {
    return _assets[target.os]?[target.arch];
  }

  /// The download URL for [asset] at [bundledVersion].
  @override
  String downloadUrlFor({required RuntimeAsset asset}) {
    final package = asset.assetName.replaceFirst("-$targetVersion.tgz", "");
    return "https://registry.npmjs.org/@opencode/$package/-/${asset.assetName}";
  }
}
