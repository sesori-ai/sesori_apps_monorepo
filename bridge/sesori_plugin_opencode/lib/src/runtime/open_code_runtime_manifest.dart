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
  static const String targetVersion = "2.3.2";

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
        sha256: "829f91179a6f4080f528d3a6756b87d2e9953debfb0a068a59bf473d2d7535a9",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-darwin-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "5724e6c56026b02b3efb60747d4ff763e50f1066970b78bbaeb32818536a7479",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-linux-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "91a937129efdae8eb8c0c5018ae533f9f35117f26ffd9a4d1f7a5f9da1e69306",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-linux-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "845468e35aa5a2b574945a0b96675e64c604f5279ced9aa7245068d8c0b6f6bb",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-windows-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "60490a66e964b82593d9edbcbdccd02b902998c54a4dd599b58efded1f8f72bc",
        archiveBinaryName: "package/bin/opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-windows-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "c079bfa785083d77997136d916d9a4c99484871098cdf02974c1383da9aa3c16",
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
