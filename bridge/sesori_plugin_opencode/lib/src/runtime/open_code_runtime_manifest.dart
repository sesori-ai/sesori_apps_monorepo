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
  static const String targetVersion = "2.0.24";

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
        sha256: "7f03cdfd90bf0ce45d4a66f1bed7e767e23b5467ad193a8455e7c6fbb1eab9a1",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-darwin-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "0c91319413e47e83f50fcf781878ed144b2972bd8901eef92fda9141800c4e88",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-linux-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "9d0cd2bfc060fd6c2afdf6db69837f8690d46a8d8327bb864421851ce004f453",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-linux-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "21b1ee0683841405d69541fc44481f8e5752e95bea72e8b8ec31dbcdb102e7f8",
        archiveBinaryName: "package/bin/opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "cli-windows-arm64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "ca6a3ba157deef69e4bbdf8cf9b1d172c57326d0b5ce50909967c91e2199466b",
        archiveBinaryName: "package/bin/opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "cli-windows-x64-$targetVersion.tgz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "6077be6fb83a97360ca1fdd094272a1c788ce6320062c04b11291f2d48b45216",
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
