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
  static const String targetVersion = "2026.09.10-fd3934a";

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
        sha256: "aec0b01ae056de48a02fe315fbf0580eb91377752d993307499988cbe0285423",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "darwin/x64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "964cc72e88125c6b48ecaaebef68bf7cb752eb7b9d010a5535cf9f8e677dcf83",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "linux/arm64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "e0494438b01c37bc34848491d1f3478ef469494c56caf020de11796d146db64a",
        archiveBinaryName: _packageBinaryName,
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "linux/x64/agent-cli-package.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "27997c8391ad853a5a732b1845db8ef82a8ba6afb0f7829cc739464f8966e96e",
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
