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
  static const String targetVersion = "2.2.7";

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
        sha256: "8d4f90c5b23faa724ba1c877d8358072bbb6565c33b8d8b5dca7c7644c4de0bf",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-darwin-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "a2f1bd02c36e180d43999a70126212511ef67686345d600724dd93ea74de7601",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-linux-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "7e74ceb64fe5704ff2fdef3dee45866efcb580d71f182a6cae29606cad1f8b52",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-linux-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "d65935464f93f07913633f977cb99723af64eeff6ae7a822722ce89bedabdd45",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-windows-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "4909131b2998e0350ba8adada6ffb31522193908d8f4a6d67b17b76c52a94f87",
        archiveBinaryName: "package/bin/opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-windows-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "666d684601380ad9f7b54a004c6fe61c2a94827fac4a6150ba131ea85e507977",
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
