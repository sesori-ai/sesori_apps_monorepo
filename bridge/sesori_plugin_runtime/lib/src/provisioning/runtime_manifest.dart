import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "runtime_version.dart";

/// How a publisher's extracted archive is placed into the version directory.
///
/// Most runtimes ship a single self-contained executable ([singleBinary]).
/// Other runtimes ship a package tree whose entry binary loads sibling files,
/// so the whole directory must be kept together ([packageDirectory]).
enum RuntimeArchiveLayout() {
  singleBinary,
  packageDirectory,
}

/// One platform's pinned release artifact for a managed runtime, identified by
/// its publisher [assetName] and verified against [sha256] before placement.
sealed class const RuntimeAsset({required final String assetName, required final String sha256});

typedef RuntimeAssetResolver = Future<RuntimeAsset?> Function({required PlatformTarget target});

/// A runtime release artifact distributed inside an archive.
///
/// [archiveBinaryName] is distinct from [RuntimeManifest.binaryFileName] (the
/// canonical on-disk name): some publishers use a target-triple member name
/// that the installer normalizes to the canonical name.
final class const ArchiveRuntimeAsset({
  required super.assetName,
  required final ArchiveFormat format,
  required super.sha256,

  /// The entry executable's name inside the extracted archive. For
  /// [RuntimeArchiveLayout.packageDirectory] this may be a relative path from
  /// the package root; the complete tree rooted above that path travels with it.
  required final String archiveBinaryName,
  required final RuntimeArchiveLayout layout,
}) extends RuntimeAsset;

/// A runtime published as a bare executable with no archive container.
final class const DirectBinaryRuntimeAsset({required super.assetName, required super.sha256}) extends RuntimeAsset;

/// The harness-specific seam of the shared runtime-provisioning system: the
/// pinned facts a [ManagedRuntimeProvisionService] needs to decide which binary
/// to launch and, when downloading, where to fetch it and how to verify it.
///
/// Everything generic (precedence, download/verify/extract/place, version
/// gating, progress reporting, stale-version sweep) lives in the shared
/// provisioning classes; each plugin implements exactly one `RuntimeManifest`.
///
/// Two version constants drive provisioning:
/// - [minPathVersion] gates a *pre-installed* (PATH) runtime: at or above it,
///   the bridge uses the user's own install; below it, the bridge falls back to
///   the managed runtime (so a too-old install can't break the bridge, and a
///   newer one is never downgraded).
/// - [bundledVersion] is the exact version the managed runtime downloads.
abstract class const RuntimeManifest() {
  /// Stable runtime identifier. Doubles as the managed-runtime subdirectory name
  /// under `PluginHost.stateDirectory` and the log tag (e.g. `"opencode"`,
  /// `"codex"`).
  String get runtimeId;

  /// Human-readable name used in user-facing provision messages (e.g.
  /// `"OpenCode"`).
  String get displayName;

  /// URL the user-facing messages point at for a manual install/upgrade.
  String get installDocsUrl;

  /// The command name probed on `PATH` to detect a pre-installed runtime (e.g.
  /// `"opencode"`, `"codex"`).
  String get pathExecutableName;

  /// The canonical executable file name or relative path under the managed
  /// version directory (platform-aware, e.g. `opencode` or `bin/codex.exe`).
  String get binaryFileName;

  /// Minimum version the bridge will use as-is, for a pre-installed (PATH)
  /// runtime and for a managed one alike: a managed version at or above it stays
  /// usable while a newer [bundledVersion] downloads, and one below it is never
  /// selected.
  RuntimeVersion get minPathVersion;

  /// The exact version the managed runtime installs.
  RuntimeVersion get bundledVersion;

  /// Parses a token of this runtime's `--version` output into its own version
  /// scheme. Keeping this with the pins guarantees probes and comparisons use
  /// one scheme per runtime.
  RuntimeVersion? parseVersion({required String value});

  /// Parses a managed version directory name under the runtime's state root.
  ///
  /// The installer names those directories with [RuntimeVersion.raw], so the
  /// default reuses [parseVersion]. Override when [parseVersion] requires a
  /// publisher-specific `--version` token (a prefix, a label) that an on-disk
  /// directory name does not carry.
  RuntimeVersion? parseInstalledVersion({required String value}) => parseVersion(value: value);

  /// The pinned asset for [target], or `null` when the platform is unsupported
  /// or requires asynchronous host-specific selection by the installer's
  /// [RuntimeAssetResolver].
  RuntimeAsset? assetFor({required PlatformTarget target});

  /// Whether managed installation is available for [target]. Runtimes whose
  /// asset choice is synchronous inherit the normal asset lookup behavior.
  bool supportsManagedInstallOn({required PlatformTarget target}) => assetFor(target: target) != null;

  /// The download URL for [asset] at [bundledVersion].
  String downloadUrlFor({required RuntimeAsset asset});

  String githubReleaseAssetUrl({required String repository, required String tag, required RuntimeAsset asset}) =>
      "https://github.com/$repository/releases/download/$tag/${asset.assetName}";

  /// Expected path of this manifest's managed binary for [version] under a
  /// plugin state root. Computing the path is read-only and does not imply that
  /// the runtime is installed or valid.
  String managedBinaryPath({required String stateDirectory, required RuntimeVersion version}) {
    return p.join(stateDirectory, runtimeId, version.raw, binaryFileName);
  }
}
