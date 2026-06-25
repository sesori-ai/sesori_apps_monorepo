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
/// published asset digests for codex `rust-v0.142.0`.
class CodexRuntimeManifest implements RuntimeManifest {
  const CodexRuntimeManifest();

  /// Minimum pre-installed codex version the bridge will use as-is.
  static final SemanticVersion _minPathVersion = SemanticVersion.parse(value: "0.139.0");

  /// The exact codex version the managed runtime installs.
  static final SemanticVersion _bundledVersion = SemanticVersion.parse(value: "0.142.0");

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
        sha256: "daa4443c455f48143d750912fa0f91d7b9456fa52972f725bc1254ae9b5a3648",
        archiveBinaryName: "codex-aarch64-apple-darwin",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "20141a58b1e077b23f0387e99afc3d76280ecd6c92ef68334344a0a379d29336",
        archiveBinaryName: "codex-x86_64-apple-darwin",
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "63fc9816f174ab4f713031e638201c49cfa7cc5f41a22b9db71010afa7e09892",
        archiveBinaryName: "codex-aarch64-unknown-linux-musl",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "2e3acb39a277ff11c314d832cfdd246faebeea26bf01aff8e9e10641e6dea801",
        archiveBinaryName: "codex-x86_64-unknown-linux-musl",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "codex-aarch64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "bfed1f82f822e4a749be336a5924d5a858949413498f6fc2ae9c1f806d3e02a9",
        archiveBinaryName: "codex-aarch64-pc-windows-msvc.exe",
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "codex-x86_64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "b109ccef543d969128e22834857343af94fe446039ff51854926b585dd136e6f",
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
