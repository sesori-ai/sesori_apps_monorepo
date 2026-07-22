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
class OpenCodeRuntimeManifest extends RuntimeManifest {
  const OpenCodeRuntimeManifest();

  /// Minimum pre-installed OpenCode version the bridge will use as-is.
  /// Conservative on purpose: prefer the user's own compatible install and
  /// only download the managed runtime for genuinely old installs.
  static final SemanticVersion _minPathVersion = SemanticVersion.parse(value: "1.14.0");

  /// The exact OpenCode version the managed runtime installs.
  static final SemanticVersion _bundledVersion = SemanticVersion.parse(value: "1.18.3");

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
        sha256: "946f62b155638b911144b7bef520ee4a6442f696297907873463bca3524e40ef",
        archiveBinaryName: "opencode",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "opencode-darwin-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "4ea147867ba19e4ec03559df557811f1674f40788aea4d10326dc563b7667c6d",
        archiveBinaryName: "opencode",
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "opencode-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "da0a631174eba380b2a1d51f9d364fa3812da433e72743c72471d4b5da59c69d",
        archiveBinaryName: "opencode",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "opencode-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "60f27b2679f00a511b6539f97e02448afaf58d9c66e2448285ea0c517ca84583",
        archiveBinaryName: "opencode",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "opencode-windows-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "a549fb2e9041db9438bcd9b77bfa0a4b2476caf2d550f37479aabfec1b079bfb",
        archiveBinaryName: "opencode.exe",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "opencode-windows-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "68bc62930f6cb5755e0409aa9de0bb270a66ed2b8c9cf0c029e9f2287ed5486e",
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
