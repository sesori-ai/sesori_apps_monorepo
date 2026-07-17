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
/// published asset digests for codex `rust-v0.144.5`.
class CodexRuntimeManifest implements RuntimeManifest {
  const CodexRuntimeManifest();

  /// Minimum pre-installed codex version the bridge will use as-is.
  static final SemanticVersion _minPathVersion = SemanticVersion.parse(value: "0.139.0");

  /// The exact codex version the managed runtime installs.
  static final SemanticVersion _bundledVersion = SemanticVersion.parse(value: "0.144.5");

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
        sha256: "a5b77d2fb393f201777809425ab28d9beb65ee0c0b2bf792f09eaf8ef1151592",
        archiveBinaryName: "codex-aarch64-apple-darwin",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "ff5c894a9ffa6d97c225c8d3c869c7ef7573dcbd0cf9b762ecfb9fa96dbb7d88",
        archiveBinaryName: "codex-x86_64-apple-darwin",
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "5433789cd66e0db3b78cccd218d894471ed9e92fe93465120d1356508952084d",
        archiveBinaryName: "codex-aarch64-unknown-linux-musl",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "b6bea13bedf493232f6717714c45e783788c695cedcf37c344f73afc97b1ec9f",
        archiveBinaryName: "codex-x86_64-unknown-linux-musl",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "e5f319f9f737605731aecf4208b7cda88df9ef0f98fa22c9935944bd7f267469",
        archiveBinaryName: "codex-aarch64-pc-windows-msvc.exe",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "c5fa9ad03f266640465da5677f2bcebd2db02a604940d1264b6a342d5136df91",
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
