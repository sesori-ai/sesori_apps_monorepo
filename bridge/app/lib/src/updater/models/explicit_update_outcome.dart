import '../foundation/release_track.dart';

/// The result of an explicit `sesori-bridge update` invocation, returned by
/// [ManualUpdateService] as pure data. The command derives its rendered output
/// and exit code from this; no `Console`/IO happens in the service.
sealed class const ExplicitUpdateOutcome();

/// How an applied release relates to the version that was running.
enum UpdateAppliedKind() {
  /// The installed release is newer than the running version.
  upgrade,

  /// The installed release equals the running version (a repair reinstall).
  reinstall,

  /// The installed release is older than the running version (e.g. forcing the
  /// latest stable while an `-internal.*` build was running).
  downgrade,
}

/// A release was staged and applied; it activates on the next launch.
final class const ExplicitUpdateApplied({
    required final String? fromVersion,
    required final String toVersion,
    required final UpdateAppliedKind kind,
    required final ReleaseTrack track,
  }) extends ExplicitUpdateOutcome;

/// Already on the latest eligible release for the active track.
final class const ExplicitUpdateAlreadyLatest({required final String version, required final ReleaseTrack track}) extends ExplicitUpdateOutcome;

/// The running binary is not eligible for the active track and the latest
/// eligible release is not newer, so a plain update can't help — suggests
/// `--force` to switch onto the track.
final class const ExplicitUpdateTrackMismatch({
    required final String currentVersion,
    required final String latestVersion,
    required final ReleaseTrack track,
  }) extends ExplicitUpdateOutcome;

/// No release eligible for the active track was found to install.
final class const ExplicitUpdateNoEligibleRelease({required final ReleaseTrack track}) extends ExplicitUpdateOutcome;

/// The command was run from a binary that is not the managed install (e.g. a
/// dev build or an arbitrary path), so there is nothing to update in place.
final class const ExplicitUpdateNotManaged({required final String executablePath}) extends ExplicitUpdateOutcome;

/// The command was run directly from an npm-owned package payload.
final class const ExplicitUpdateNpmDirect({required final String message}) extends ExplicitUpdateOutcome;

/// Another update is already in progress (the update lock is held).
final class const ExplicitUpdateLockBusy() extends ExplicitUpdateOutcome;

/// The update failed (network, rate limit, checksum, permission, swap, …).
/// [logPath] points at the durable update log when one is available.
final class const ExplicitUpdateFailed({required final String reason, required final String? logPath}) extends ExplicitUpdateOutcome;
