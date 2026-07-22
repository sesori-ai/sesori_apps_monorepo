import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

/// One platform's pinned release archive for a managed runtime: the asset name,
/// its container [format], the SHA-256 the download is verified against, and the
/// name of the executable file *inside* the extracted archive.
///
/// [archiveBinaryName] is distinct from [RuntimeManifest.binaryFileName] (the
/// canonical on-disk name the binary is placed under): some publishers ship the
/// executable under a target-triple name (e.g. `codex-aarch64-apple-darwin`)
/// that must be normalized to a plain `codex`. For publishers whose archive
/// member already matches the canonical name (e.g. OpenCode's `opencode`), the
/// two are equal.
final class RuntimeAsset {
  const RuntimeAsset({
    required this.assetName,
    required this.format,
    required this.sha256,
    required this.archiveBinaryName,
  });

  final String assetName;
  final ArchiveFormat format;
  final String sha256;
  final String archiveBinaryName;
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
  SemanticVersion get minPathVersion;

  /// The exact version the managed runtime installs.
  SemanticVersion get bundledVersion;

  /// The pinned asset for [target], or `null` when the platform is unsupported.
  RuntimeAsset? assetFor({required PlatformTarget target});

  /// The download URL for [asset] at [bundledVersion].
  String downloadUrlFor({required RuntimeAsset asset});

  /// Expected path of this manifest's pinned managed binary under a plugin
  /// state root. Computing the path is read-only and does not imply that the
  /// runtime is installed or valid.
  String managedBinaryPath({required String stateDirectory}) {
    return p.join(stateDirectory, runtimeId, bundledVersion.toString(), binaryFileName);
  }
}
