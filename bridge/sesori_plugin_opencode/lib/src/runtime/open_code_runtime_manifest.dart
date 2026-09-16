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
  static const String targetVersion = "1.18.30";

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
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "a5e43d6887386efc7d68ce49ae28e3bbdfdee3dfd1d7169b612c3ce67e53b1e8",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-darwin-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "7453007e58ff122401438d95ccb24334874b5908dcaee77883f96c23395d5710",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "opencode-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "4111a55c2a02c0fac314bd51e9a2330280e6d29d2b85b9554fff6d62612566ed",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "55007246858165496ff85ba1c2b648f7421e8e2013bf4189a680c9ff8e699d17",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "opencode-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "35d6ff7d80aff5ade71ac06fc32dd89357b5b0bac050fc6db41ecf0929cea560",
        archiveBinaryName: "opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "c8c0e0d05ac3dac544a0edfad8de9eb244bf46c6c7a131c38619d40fcf31bd1f",
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
