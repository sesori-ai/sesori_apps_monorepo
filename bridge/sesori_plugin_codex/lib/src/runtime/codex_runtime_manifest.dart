import "dart:io" show Platform;

import "package:path/path.dart" as p;
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
/// published asset digests for codex `rust-v0.153.4`.
class const CodexRuntimeManifest() extends RuntimeManifest {
  /// Minimum pre-installed codex version the bridge will use as-is.
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.139.0");

  /// The latest stable codex release targeted by this plugin.
  static const String targetVersion = "0.153.4";

  /// The exact codex version the managed runtime installs.
  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  /// Pinned per-platform assets for [bundledVersion]. Codex's canonical package
  /// archives contain the CLI, `codex-code-mode-host`, and runtime resources.
  /// The complete package tree must remain intact because the CLI resolves its
  /// helper and resources relative to `bin/codex` (`bin/codex.exe` on Windows).
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "codex-package-aarch64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "35438da1fbf7a6db7ddb3bcec84448fa6015ba188461472a97d9d1da7d9c4353",
        archiveBinaryName: "bin/codex",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-package-x86_64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "3ee638d7155c856ef31f3f4a85cb2195de1939962d3924c935b24f0514564a3d",
        archiveBinaryName: "bin/codex",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "codex-package-aarch64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "fc395cb043a1093ab0db34f44aba3199bfaa9ce640cd9be7fd588f44b0da64a4",
        archiveBinaryName: "bin/codex",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-package-x86_64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "a822187e1a2420c61c5926721bfbd878701ed95547c9bb0d4de4498a16ba1821",
        archiveBinaryName: "bin/codex",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "codex-package-aarch64-pc-windows-msvc.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "ac51b1a5932e07dffcaa6e98f4801f13b25192094739b732fc8b40ddb41bbda2",
        archiveBinaryName: "bin/codex.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-package-x86_64-pc-windows-msvc.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "a6ef3442cb12766a88b39311d79244289e4f9763e2c53ff4fbebc2cb653cc5f3",
        archiveBinaryName: "bin/codex.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
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
  String get binaryFileName => p.join("bin", Platform.isWindows ? "codex.exe" : "codex");

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
  String downloadUrlFor({required RuntimeAsset asset}) =>
      githubReleaseAssetUrl(repository: "openai/codex", tag: "rust-v${bundledVersion.raw}", asset: asset);
}
