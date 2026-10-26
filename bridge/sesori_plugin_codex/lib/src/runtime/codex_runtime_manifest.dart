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
/// published asset digests for codex `rust-v0.164.0`.
class const CodexRuntimeManifest() extends RuntimeManifest {
  /// Minimum pre-installed codex version the bridge will use as-is.
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.139.0");

  /// The latest stable codex release targeted by this plugin.
  static const String targetVersion = "0.164.0";

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
        sha256: "dd99e9092270691a67bdde7be04ac283dea9da8e86cbde356c2cc851a79205fa",
        archiveBinaryName: "bin/codex",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-package-x86_64-apple-darwin.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "cfb2a9988d7ea448511166a35789af07a0065d1117db54350b17d46cf03d0294",
        archiveBinaryName: "bin/codex",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "codex-package-aarch64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "5918add6c7e9cf1e14a9af1b4c0f4bf1d24a43903faac26df5dc4c019ea91bd5",
        archiveBinaryName: "bin/codex",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-package-x86_64-unknown-linux-musl.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "3ec55053109608d5038f7e50750f7d25f768dfd740fef071aa710e2559b63aac",
        archiveBinaryName: "bin/codex",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "codex-package-aarch64-pc-windows-msvc.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "735deb6af84fd927084429f7a371ee38670a013baace6df24985780f7ef67355",
        archiveBinaryName: "bin/codex.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "codex-package-x86_64-pc-windows-msvc.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "700116be3143576d006467af8576f7f4c9dada1feddfdb7f69743bfde0997018",
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
