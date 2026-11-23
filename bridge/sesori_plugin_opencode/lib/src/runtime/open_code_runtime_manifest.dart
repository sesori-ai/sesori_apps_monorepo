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
  static const String targetVersion = "2.4.1";

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
        sha256: "fb9aef3318e14a138aef283caa2a6c9a7278b21ec734baa3f52c00562b77dbc5",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-darwin-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "2dd7afa9164b216df0ca001be515703d23234e56e8e4d56b07e5f9e110529840",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-linux-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "9eb4567ff0fab90b6dac106f786652a0ec15d65e25ffbcbb106e5ed1cee4f4e2",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-linux-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "9dbef68f231a311b56441c73c7bec01f6d87ebe44523ad14a7ba4716ff5c2031",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-windows-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "417be6ba8dace1f67ecffebd39034f37e4fa0e2196be76f8914b26477cbea919",
        archiveBinaryName: "package/bin/opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-windows-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "35edfb4c3ce5870c4f0254b1141c365aad052155ad65e5fcc9b3b54e50c693f7",
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
