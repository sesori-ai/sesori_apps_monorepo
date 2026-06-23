import '../foundation/release_track.dart';

/// The result of an explicit `sesori-bridge update` invocation, returned by
/// [ManualUpdateService] as pure data. The command derives its rendered output
/// and exit code from this; no `Console`/IO happens in the service.
sealed class ExplicitUpdateOutcome {
  const ExplicitUpdateOutcome();
}

/// How an applied release relates to the version that was running.
enum UpdateAppliedKind {
  /// The installed release is newer than the running version.
  upgrade,

  /// The installed release equals the running version (a repair reinstall).
  reinstall,

  /// The installed release is older than the running version (e.g. forcing the
  /// latest stable while an `-internal.*` build was running).
  downgrade,
}

/// A release was staged and applied; it activates on the next launch.
final class ExplicitUpdateApplied extends ExplicitUpdateOutcome {
  final String? fromVersion;
  final String toVersion;
  final UpdateAppliedKind kind;
  final ReleaseTrack track;

  const ExplicitUpdateApplied({
    required this.fromVersion,
    required this.toVersion,
    required this.kind,
    required this.track,
  });
}

/// Already on the latest eligible release for the active track.
final class ExplicitUpdateAlreadyLatest extends ExplicitUpdateOutcome {
  final String version;
  final ReleaseTrack track;

  const ExplicitUpdateAlreadyLatest({required this.version, required this.track});
}

/// The running binary is not eligible for the active track and the latest
/// eligible release is not newer, so a plain update can't help — suggests
/// `--force` to switch onto the track.
final class ExplicitUpdateTrackMismatch extends ExplicitUpdateOutcome {
  final String currentVersion;
  final String latestVersion;
  final ReleaseTrack track;

  const ExplicitUpdateTrackMismatch({
    required this.currentVersion,
    required this.latestVersion,
    required this.track,
  });
}

/// No release eligible for the active track was found to install.
final class ExplicitUpdateNoEligibleRelease extends ExplicitUpdateOutcome {
  final ReleaseTrack track;

  const ExplicitUpdateNoEligibleRelease({required this.track});
}

/// The command was run from a binary that is not the managed install (e.g. a
/// dev build or an arbitrary path), so there is nothing to update in place.
final class ExplicitUpdateNotManaged extends ExplicitUpdateOutcome {
  final String executablePath;

  const ExplicitUpdateNotManaged({required this.executablePath});
}

/// The command was run directly from an npm-owned package payload.
final class ExplicitUpdateNpmDirect extends ExplicitUpdateOutcome {
  final String message;

  const ExplicitUpdateNpmDirect({required this.message});
}

/// Another update is already in progress (the update lock is held).
final class ExplicitUpdateLockBusy extends ExplicitUpdateOutcome {
  const ExplicitUpdateLockBusy();
}

/// The update failed (network, rate limit, checksum, permission, swap, …).
/// [logPath] points at the durable update log when one is available.
final class ExplicitUpdateFailed extends ExplicitUpdateOutcome {
  final String reason;
  final String? logPath;

  const ExplicitUpdateFailed({required this.reason, required this.logPath});
}
