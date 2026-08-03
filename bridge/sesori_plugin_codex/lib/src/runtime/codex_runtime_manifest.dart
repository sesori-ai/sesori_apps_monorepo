import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

/// Pinned facts about the codex CLI runtime the bridge can install and gate, as a
/// [RuntimeManifest] consumed by the shared `ManagedRuntimeProvisionService`.
///
/// Two version constants drive provisioning:
/// - [minPathVersion] gates a *pre-installed* (PATH) codex: at or above it the
///   bridge uses the user's own install; below it the bridge falls back to the
///   managed runtime. `0.139.0` is the floor the bridge's `app-server` v2
///   protocol assumes (see `codex_app_server_client.dart`, which opts into a
///   capability codex added in 0.139.0).
/// - [_bundledVersion] is the exact version the managed runtime downloads.
///
/// ## Bumping codex
/// Bumping codex is a deliberate release-engineering act: change [_bundledVersion],
/// refresh the matching SHA-256 hashes in [_assets] from the GitHub release's
/// published asset digests (the release asset `digest` field, verified against
/// the downloaded archive), confirm the [_assets] filenames still match the
/// release, raise [minPathVersion] only if the bridge starts to require a newer
/// codex API, and re-run the integration tests. The hashes below are the
/// published asset digests for codex `rust-v0.146.0`.
class CodexRuntimeManifest extends RuntimeManifest {
  const CodexRuntimeManifest();

  /// Minimum pre-installed codex version the bridge will use as-is.
  static final SemanticVersion _minPathVersion = SemanticVersion.parse(value: "0.139.0");

  /// The exact codex version the managed runtime installs.
  static final SemanticVersion _bundledVersion = SemanticVersion.parse(value: "0.146.0");

  static const String _releaseBaseUrl = "https://github.com/openai/codex/releases/download";

  /// Pinned per-platform assets for [bundledVersion]. codex ships `.tar.gz` on
  /// darwin/linux and an `.exe.zip` on windows; the binary inside each archive is
  /// named with the full target triple (e.g. `codex-aarch64-apple-darwin`), so
  /// [RuntimeAsset.archiveBinaryName] carries that member name and the installer
  /// normalizes it to the canonical [binaryFileName] (`codex` / `codex.exe`).
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "2750132d300e64f1dbffb95e3d913fd9c9dc7812bc8e1bce5c61357248b7929e",
        archiveBinaryName: "codex-aarch64-apple-darwin",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "710d727b0fa2b4ab2189eb1bdc5ab40177c168296af264913eb7ab3ce848d04b",
        archiveBinaryName: "codex-x86_64-apple-darwin",
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "975bac91562abeedeb8f79636d51a86649b31f34a9de6a3bcb059565b6cf1f87",
        archiveBinaryName: "codex-aarch64-unknown-linux-musl",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "5ba3b9405543953081f661d0854d266f76e2abbe51d41349355a36de7673776a",
        archiveBinaryName: "codex-x86_64-unknown-linux-musl",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "5219938c0138580611735d8c2a79b100be0929083f779a8f375aadf192175b33",
        archiveBinaryName: "codex-aarch64-pc-windows-msvc.exe",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "4781b618fa3a16d91c892f8a1e2c82625f9286f9bb944a5690ba727c84fc5729",
        archiveBinaryName: "codex-x86_64-pc-windows-msvc.exe",
      ),
    },
  };

  @override
  String get runtimeId => "codex";

  @override
  String get displayName => "Codex";

  @override
  String get installDocsUrl => "https://github.com/openai/codex";

  @override
  String get pathExecutableName => "codex";

  @override
  String get binaryFileName => Platform.isWindows ? "codex.exe" : "codex";

  @override
  SemanticVersion get minPathVersion => _minPathVersion;

  @override
  SemanticVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) {
    return _assets[target.os]?[target.arch];
  }

  @override
  String downloadUrlFor({required RuntimeAsset asset}) {
    return "$_releaseBaseUrl/rust-v$bundledVersion/${asset.assetName}";
  }
}
