import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

/// Pinned facts about the Cursor CLI runtime the bridge can install and gate,
/// as a [RuntimeManifest] consumed by the shared managed-runtime services.
///
/// Cursor differs from OpenCode and codex in three ways that shape this file:
///
/// 1. **Calendar versions.** Builds are `YYYY.MM.DD-<suffix>` (e.g.
///    `2026.08.11-e8db854`, and historically `2026.06.15-18-00-12-6f5a2cf`).
///    Semver cannot express these: the multi-dash form fails to parse at all,
///    and a dated build would sort *below* the same day's bare version because
///    semver treats the suffix as a prerelease. Cursor therefore pins
///    [CalendarRuntimeVersion], which orders on the date and ignores the
///    build suffix.
/// 2. **No published checksums.** Cursor serves the archive straight from
///    `downloads.cursor.com` with no digest manifest, so the SHA-256 values
///    below are computed by us at pin time (see the `update-backend-runtimes`
///    skill). A silently re-published asset therefore fails verification with a
///    clear message instead of installing unverified bytes — fail closed.
/// 3. **A package directory, not a lone binary.** The archive contains a
///    `dist-package/` tree whose `cursor-agent` entry binary loads sibling
///    files (node runtime, native modules), so the assets declare
///    [RuntimeArchiveLayout.packageDirectory] and the whole tree is installed.
///
/// Windows is deliberately absent: Cursor publishes darwin and linux only, so
/// [assetFor] returns null there and the descriptor does not advertise the
/// install capability.
///
/// ## Bumping Cursor
/// Change [targetVersion], re-download all four assets, recompute their
/// SHA-256 values, and raise [minPathVersion] only when bridge behavior needs a
/// newer Cursor capability.
class const CursorRuntimeManifest() extends RuntimeManifest {
  /// Minimum pre-installed (PATH) Cursor CLI build the bridge uses as-is.
  /// Earlier builds advertise `acp` model switching and `session/load` but
  /// silently no-op them, so the experience breaks invisibly.
  static final CalendarRuntimeVersion _minPathVersion = CalendarRuntimeVersion.parse(value: "2026.07.16");

  /// The latest official-installer Cursor build targeted by this plugin.
  static const String targetVersion = "2026.09.23-86fc751";

  /// The exact Cursor CLI build the managed runtime installs, preserved
  /// verbatim: [CalendarRuntimeVersion] keeps the publisher's string, so the
  /// download URL and the on-disk version directory both use it unchanged.
  static final CalendarRuntimeVersion _bundledVersion = CalendarRuntimeVersion.parse(
    value: targetVersion,
  );

  static const String _downloadBaseUrl = "https://downloads.cursor.com/lab";

  /// The entry executable inside the published `dist-package/` tree.
  static const String _packageBinaryName = "cursor-agent";

  /// Pinned per-platform assets for [bundledVersion]. Cursor serves the same
  /// `agent-cli-package.tar.gz` filename under a platform-specific path, so
  /// each asset name carries its `<os>/<arch>/` prefix and the download URL
  /// stays a pure function of the asset.
  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "darwin/arm64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "fa3fe13d5589c586ff132a24c16eea96fb8efde88afdefddcd11d80fa199f3a5",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "darwin/x64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "809335cd4a92f7c11a20f605213585b6136c7bfe6722069facf94e988d3ed0e7",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "linux/arm64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "38d1482c945172926e780206fce8cc51c67dd4f96162bcec680903aa70d80417",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "linux/x64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "740dd9d6eb5aec36ca90eaedf9fd5e2c489cd674d69b5147b3c2670f02d9776d",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeArchiveLayout.packageDirectory,
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
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeVersion? parseVersion({required String value}) => CalendarRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) {
    return _assets[target.os]?[target.arch];
  }

  @override
  String downloadUrlFor({required RuntimeAsset asset}) {
    return "$_downloadBaseUrl/${bundledVersion.raw}/${asset.assetName}";
  }
}
