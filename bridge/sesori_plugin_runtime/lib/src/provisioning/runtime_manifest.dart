import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "runtime_version.dart";

/// How a publisher's extracted archive is placed into the version directory.
///
/// Most runtimes ship a single self-contained executable ([singleBinary]).
/// Cursor ships a `dist-package/` tree whose entry binary loads sibling files,
/// so the whole directory must be kept together ([packageDirectory]).
enum RuntimeArchiveLayout { singleBinary, packageDirectory }

/// One platform's pinned release artifact for a managed runtime, identified by
/// its publisher [assetName] and verified against [sha256] before placement.
sealed class RuntimeAsset {
  const RuntimeAsset({
    required this.assetName,
    required this.sha256,
  });

  final String assetName;
  final String sha256;
}

typedef RuntimeAssetResolver = Future<RuntimeAsset?> Function({required PlatformTarget target});

/// A runtime release artifact distributed inside an archive.
///
/// [archiveBinaryName] is distinct from [RuntimeManifest.binaryFileName] (the
/// canonical on-disk name): some publishers use a target-triple member name
/// that the installer normalizes to the canonical name.
final class ArchiveRuntimeAsset extends RuntimeAsset {
  const ArchiveRuntimeAsset({
    required super.assetName,
    required this.format,
    required super.sha256,
    required this.archiveBinaryName,
    required this.layout,
  });

  final ArchiveFormat format;

  /// The entry executable's name inside the extracted archive. For
  /// [RuntimeArchiveLayout.packageDirectory] it names the binary within the
  /// placed tree; its siblings travel with it.
  final String archiveBinaryName;

  final RuntimeArchiveLayout layout;
}

/// A runtime published as a bare executable with no archive container.
final class DirectBinaryRuntimeAsset extends RuntimeAsset {
  const DirectBinaryRuntimeAsset({required super.assetName, required super.sha256});
}

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
abstract class RuntimeManifest {
  const RuntimeManifest();

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

  /// The canonical executable file name the managed binary is placed under in
  /// its version directory (platform-aware, e.g. `codex` / `codex.exe`).
  String get binaryFileName;

  /// Minimum pre-installed (PATH) version the bridge will use as-is.
  RuntimeVersion get minPathVersion;

  /// The exact version the managed runtime installs.
  RuntimeVersion get bundledVersion;

  /// Parses a token of this runtime's `--version` output into its own version
  /// scheme. Keeping this with the pins guarantees probes and comparisons use
  /// one scheme per runtime.
  RuntimeVersion? parseVersion({required String value});

  /// The pinned asset for [target], or `null` when the platform is unsupported.
  RuntimeAsset? assetFor({required PlatformTarget target});

  /// The download URL for [asset] at [bundledVersion].
  String downloadUrlFor({required RuntimeAsset asset});

  /// Expected path of this manifest's pinned managed binary under a plugin
  /// state root. Computing the path is read-only and does not imply that the
  /// runtime is installed or valid.
  String managedBinaryPath({required String stateDirectory}) {
    return p.join(stateDirectory, runtimeId, bundledVersion.raw, binaryFileName);
  }
}
