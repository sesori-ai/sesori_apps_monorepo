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
class OpenCodeRuntimeManifest implements RuntimeManifest {
  const OpenCodeRuntimeManifest();

  /// Minimum pre-installed OpenCode version the bridge will use as-is.
  /// Conservative on purpose: prefer the user's own install whenever it is a
  /// 1.x, and only download the managed runtime for genuinely old installs.
  static final SemanticVersion _minPathVersion = SemanticVersion.parse(value: "1.0.0");

  /// The exact OpenCode version the managed runtime installs.
  static final SemanticVersion _bundledVersion = SemanticVersion.parse(value: "1.17.9");

  static const String _releaseBaseUrl = "https://github.com/anomalyco/opencode/releases/download";

  /// Pinned per-platform assets for [bundledVersion]. darwin/windows ship `.zip`,
  /// linux ships `.tar.gz`; the non-baseline, non-musl CLI builds are used. The
  /// OpenCode archives contain the executable under its plain canonical name, so
  /// [RuntimeAsset.archiveBinaryName] equals [binaryFileName] per platform.
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "opencode-darwin-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "913d813a88ca4f6209b9c48e548bd376eef4d1e74c2bb113aa91aa96c784d332",
        archiveBinaryName: "opencode",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "opencode-darwin-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "8174a53ab3f8bbcc633c6e7d914258f1572e133bd008882c489cb4dbac60115d",
        archiveBinaryName: "opencode",
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "opencode-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "8cc511f9794e575e5d3c4c2654930d05670186df649c26b50889ac73c65dde21",
        archiveBinaryName: "opencode",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "opencode-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "85aeac95258d409d16ca34f1cfcd74c78d9d1a70b0a4154128b588e1405384f9",
        archiveBinaryName: "opencode",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "opencode-windows-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "0c58626e572a227d3b93ef8ec545d95b85a266232d8d38395600d693b05c7463",
        archiveBinaryName: "opencode.exe",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "opencode-windows-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "d1a97aa05e5795dbb8591b9732d9eafb7723de7952b884d05986a51fd31294c7",
        archiveBinaryName: "opencode.exe",
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
  SemanticVersion get minPathVersion => _minPathVersion;

  @override
  SemanticVersion get bundledVersion => _bundledVersion;

  /// The pinned asset for [target], or `null` when the platform is unsupported.
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
