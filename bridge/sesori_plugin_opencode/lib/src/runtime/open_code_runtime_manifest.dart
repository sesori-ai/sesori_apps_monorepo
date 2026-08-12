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
/// 2. Update [_bundledVersion].
/// 3. Replace all six [_assets] SHA-256 values with that release's asset digests
///    (GitHub's release API exposes each asset's `digest: "sha256:…"`).
/// 4. Raise [_minPathVersion] only if the new bridge code requires a newer
///    OpenCode API than older installs provide.
class const OpenCodeRuntimeManifest() extends RuntimeManifest {
  /// Minimum pre-installed OpenCode version the bridge will use as-is.
  /// Conservative on purpose: prefer the user's own compatible install and
  /// only download the managed runtime for genuinely old installs.
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "1.14.0");

  /// The exact OpenCode version the managed runtime installs.
  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: "1.18.11");

  static const String _releaseBaseUrl = "https://github.com/anomalyco/opencode/releases/download";

  /// Pinned per-platform assets for [bundledVersion]. darwin/windows ship `.zip`,
  /// linux ships `.tar.gz`; the non-baseline, non-musl CLI builds are used. The
  /// OpenCode archives contain the executable under its plain canonical name, so
  /// [ArchiveRuntimeAsset.archiveBinaryName] equals [binaryFileName] per platform.
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "opencode-darwin-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "188ff6a716bcd40e33ac62f17f4aec9bd760164fa6a2cde66f779a5db4abc7ce",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-darwin-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "95953ab2aca4322b90690bf34697cc9b47b6a7c72f78e7c469056fb589124d31",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "opencode-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "03e07aa461ac241dfa8c7ab54ed58c7a0e911c62fc3cb490b83e4fb3424eb73b",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "a4dffcc00a5a93256c6bd06aa0c984320528f564db52a1f4becd5c7de9fb59a1",
        archiveBinaryName: "opencode",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "opencode-windows-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "4510ccf446284f5492438c4b40b23895dc7ae78cb5eb4e7f51cbe998c1148d58",
        archiveBinaryName: "opencode.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "opencode-windows-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "f3a5ea814aecc692a4e04259d9005283f364225b38456c90f9a47b7a9d83c0e9",
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
  String downloadUrlFor({required RuntimeAsset asset}) {
    return "$_releaseBaseUrl/v$bundledVersion/${asset.assetName}";
  }
}
