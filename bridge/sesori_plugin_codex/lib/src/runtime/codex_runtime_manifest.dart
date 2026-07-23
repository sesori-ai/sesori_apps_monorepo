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
/// published asset digests for codex `rust-v0.145.0`.
class CodexRuntimeManifest extends RuntimeManifest {
  const CodexRuntimeManifest();

  /// Minimum pre-installed codex version the bridge will use as-is.
  static final SemanticVersion _minPathVersion = SemanticVersion.parse(value: "0.139.0");

  /// The exact codex version the managed runtime installs.
  static final SemanticVersion _bundledVersion = SemanticVersion.parse(value: "0.145.0");

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
        sha256: "072a30a65f05666735889ef0f60b56db186adbdde9d5c5cc1a64be0b598530fe",
        archiveBinaryName: "codex-aarch64-apple-darwin",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "4216d7a40aa49d74b65fab93d2a86d2e25a902482b827dbdb3f357777b09fadf",
        archiveBinaryName: "codex-x86_64-apple-darwin",
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "d384f90bc842450b42bd675feef06a12a46a3b1ca97efcb22566b270e4a11227",
        archiveBinaryName: "codex-aarch64-unknown-linux-musl",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "bfaf13c9ba34f2ad764e4a916c49cf7177aeba329cf0f719e2227566fc8d662a",
        archiveBinaryName: "codex-x86_64-unknown-linux-musl",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "e38667194ddf24dfeb877ab9f6346b55bd979ff52bee9dbf4123e2a48f3627e2",
        archiveBinaryName: "codex-aarch64-pc-windows-msvc.exe",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "bc6ae808bf5a9cdf113364ac281594d6da76dc103c19129e9d32caed54ec3cda",
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
