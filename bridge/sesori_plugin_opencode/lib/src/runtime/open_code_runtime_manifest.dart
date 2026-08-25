import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

/// Pinned facts about the OpenCode runtime the bridge can install and gate, as a
/// [RuntimeManifest] consumed by the shared `ManagedRuntimeProvisionService`.
///
/// Two version constants drive provisioning:
/// - [minPathVersion] gates a *pre-installed* (PATH) OpenCode: at or above it,
///   the bridge uses the user's own install; below it, the bridge falls back to
///   the managed runtime (so a too-old install can't break the bridge, and a
///   newer one is never downgraded — important because OpenCode migrates its
///   local DB on launch).
/// - [bundledVersion] is the exact version the managed runtime downloads.
///
/// ## Bumping the bundled runtime
/// 1. Pick the new `vX.Y.Z` release of `anomalyco/opencode`.
/// 2. Update [targetVersion].
/// 3. Replace all six [_assets] SHA-256 values with that release's asset digests
///    (GitHub's release API exposes each asset's `digest: "sha256:…"`).
/// 4. Raise [_minPathVersion] only if the new bridge code requires a newer
///    OpenCode API than older installs provide.
class const OpenCodeRuntimeManifest() extends RuntimeManifest {
  /// Minimum pre-installed OpenCode version the bridge will use as-is.
  /// Conservative on purpose: prefer the user's own compatible install and
  /// only download the managed runtime for genuinely old installs.
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "1.14.0");

  /// The latest stable OpenCode release targeted by this plugin.
  static const String targetVersion = "1.18.19";

  /// The exact OpenCode version the managed runtime installs.
  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  /// Pinned per-platform assets for [bundledVersion]. darwin/windows ship `.zip`,
  /// linux ships `.tar.gz`; the non-baseline, non-musl CLI builds are used. The
  /// OpenCode archives contain the executable under its plain canonical name, so
  /// [ArchiveRuntimeAsset.archiveBinaryName] equals [binaryFileName] per platform.
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "opencode-darwin-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "0026326bd77a3277ab3726be237410b19389f7829e8bb3c82dfaf9044162067c",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-darwin-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "ee495d7c30263c2cecb81a4558a9c4d29ac7b27c1df822e9d344a69cb56a75c3",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "opencode-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "506f98a1f618551f1f6fc5dcf591f824bef9d6819d40b27928ad7febcb7c363b",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "7bb35487c55f9957f5d91ae60be6fa49fc8f74629c210c1719ed75fdbf7e2bd9",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "opencode-windows-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "2e74619988a54f76837370862c0761c6595a1224ce4cd6da588975e1396a33a7",
        archiveBinaryName: "opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-windows-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "4381328bf6d611996c33d98daef27e89d274cb8391709fa1e36723f1d2899877",
        archiveBinaryName: "opencode.exe",
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

  /// The executable file name inside the extracted archive.
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
  String downloadUrlFor({required RuntimeAsset asset}) =>
      githubReleaseAssetUrl(repository: "anomalyco/opencode", tag: "v${bundledVersion.raw}", asset: asset);
}
