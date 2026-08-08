import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

/// Pinned facts about the Cursor CLI runtime the bridge can install and gate,
/// as a [RuntimeManifest] consumed by the shared managed-runtime services.
///
/// Cursor differs from OpenCode and codex in three ways that shape this file:
///
/// 1. **Calendar versions.** Builds are `YYYY.MM.DD-<hash>` (e.g.
///    `2026.08.04-aaa8809`), which parses as a semantic version with the build
///    hash as its prerelease segment, so ordering still works.
/// 2. **No published checksums.** Cursor serves the archive straight from
///    `downloads.cursor.com` with no digest manifest, so the SHA-256 values
///    below are computed by us at pin time (see the `update-backend-runtimes`
///    skill). A silently re-published asset therefore fails verification with a
///    clear message instead of installing unverified bytes — fail closed.
/// 3. **A package directory, not a lone binary.** The archive contains a
///    `dist-package/` tree whose `cursor-agent` entry binary loads sibling
///    files (node runtime, native modules), so the assets declare
///    [RuntimeAssetLayout.packageDirectory] and the whole tree is installed.
///
/// Windows is deliberately absent: Cursor publishes darwin and linux only, so
/// [assetFor] returns null there and the descriptor does not advertise the
/// install capability.
///
/// ## Bumping Cursor
/// Change [_bundledVersion], re-download all four assets, recompute their
/// SHA-256 values, and raise [minPathVersion] only when bridge behavior needs a
/// newer Cursor capability.
class CursorRuntimeManifest extends RuntimeManifest {
  const CursorRuntimeManifest();

  /// Minimum pre-installed (PATH) Cursor CLI build the bridge uses as-is.
  /// Earlier builds advertise `acp` model switching and `session/load` but
  /// silently no-op them, so the experience breaks invisibly.
  static final SemanticVersion _minPathVersion = SemanticVersion.parse(value: "2026.07.16");

  /// The exact Cursor CLI build the managed runtime installs.
  static final SemanticVersion _bundledVersion = SemanticVersion.parse(value: _bundledBuild);

  /// The build string exactly as Cursor publishes it. [SemanticVersion] drops
  /// the leading zeros (`2026.08.04` parses to `2026.8.4`), so the download URL
  /// must use this raw form rather than the parsed version's `toString()`.
  static const String _bundledBuild = "2026.08.04-aaa8809";

  static const String _downloadBaseUrl = "https://downloads.cursor.com/lab";

  /// The entry executable inside the published `dist-package/` tree.
  static const String _packageBinaryName = "cursor-agent";

  /// Pinned per-platform assets for [bundledVersion]. Cursor serves the same
  /// `agent-cli-package.tar.gz` filename under a platform-specific path, so
  /// each asset name carries its `<os>/<arch>/` prefix and the download URL
  /// stays a pure function of the asset.
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "darwin/arm64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "fc1d267622ff806a33dbf516148b9fd3957807f4d931c763118c269f92b535fc",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeAssetLayout.packageDirectory,
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "darwin/x64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "3b2b95fa681745f30b1d031e67d23c1a19934ed42f39dea3ab7d2d7728320aa5",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeAssetLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: RuntimeAsset(
        assetName: "linux/arm64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "d5196289292a660b59807ac508c9ac36ec1e1a1a7e4697af3ef6824fdea984ee",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeAssetLayout.packageDirectory,
      ),
      PlatformArch.x64: RuntimeAsset(
        assetName: "linux/x64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "e282068dcb5cdd668b8ce2e3456c58be13bb64a834e1ad49f8534b5cd7aa2fe5",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeAssetLayout.packageDirectory,
      ),
    },
  };

  @override
  String get runtimeId => "cursor";

  @override
  String get displayName => "Cursor";

  @override
  String get installDocsUrl => "https://cursor.com/install";

  @override
  String get pathExecutableName => "cursor-agent";

  @override
  String get binaryFileName => _packageBinaryName;

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
    return "$_downloadBaseUrl/$_bundledBuild/${asset.assetName}";
  }
}
