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
/// - [targetVersion] is the latest stable release targeted by the plugin, and
///   [_bundledVersion] is the exact version the managed runtime downloads.
///
/// ## Bumping codex
/// Bumping codex is a deliberate release-engineering act: change [targetVersion],
/// refresh the matching SHA-256 hashes in [_assets] from the GitHub release's
/// published asset digests (the release asset `digest` field, verified against
/// the downloaded archive), confirm the [_assets] filenames still match the
/// release, raise [minPathVersion] only if the bridge starts to require a newer
/// codex API, and re-run the integration tests. The hashes below are the
/// published asset digests for codex `rust-v0.148.0`.
class const CodexRuntimeManifest() extends RuntimeManifest {
  /// Minimum pre-installed codex version the bridge will use as-is.
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.139.0");

  /// The latest stable codex release targeted by this plugin.
  static const String targetVersion = "0.148.0";

  /// The exact codex version the managed runtime installs.
  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const String _releaseBaseUrl = "https://github.com/openai/codex/releases/download";

  /// Pinned per-platform assets for [bundledVersion]. codex ships `.tar.gz` on
  /// darwin/linux and an `.exe.zip` on windows; the binary inside each archive is
  /// named with the full target triple (e.g. `codex-aarch64-apple-darwin`), so
  /// [ArchiveRuntimeAsset.archiveBinaryName] carries that member name and the installer
  /// normalizes it to the canonical [binaryFileName] (`codex` / `codex.exe`).
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "codex-aarch64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "758916aa38efa7ad076a050830fcbef1a7ed6f41efae9c1cceaeef63e428fc2b",
        archiveBinaryName: "codex-aarch64-apple-darwin",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-x86_64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "54591772f242271f802f17b4dda6cecab29229ba71593e962e208549e0da1a3a",
        archiveBinaryName: "codex-x86_64-apple-darwin",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "codex-aarch64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "410c6ae0c763eb39c6da17665e63f9aa4a98e6ee663d81f8e8b779c97cb175ac",
        archiveBinaryName: "codex-aarch64-unknown-linux-musl",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-x86_64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "1a36f762f6b3bef533bb86345ad9517661c2d84d53996a250cf2ca89d2cfee5a",
        archiveBinaryName: "codex-x86_64-unknown-linux-musl",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "codex-aarch64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "73a2b150965d63ddc71f7d0b5a3845a5d5925757af6495110a32dea40d6e18c3",
        archiveBinaryName: "codex-aarch64-pc-windows-msvc.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-x86_64-pc-windows-msvc.exe.zip",
        format: ArchiveFormat.zip,
        sha256: "a3f053e70bd5073d04d08ee3a2605b4015c74b0a51f3ff5a2fb67852ee37e3b0",
        archiveBinaryName: "codex-x86_64-pc-windows-msvc.exe",
        layout: RuntimeArchiveLayout.singleBinary,
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
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) {
    return _assets[target.os]?[target.arch];
  }

  @override
  String downloadUrlFor({required RuntimeAsset asset}) {
    return "$_releaseBaseUrl/rust-v$bundledVersion/${asset.assetName}";
  }
}
