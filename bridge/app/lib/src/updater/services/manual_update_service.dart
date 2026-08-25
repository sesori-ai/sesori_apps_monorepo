import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';

import '../foundation/github_rate_limit_exception.dart';
import '../foundation/release_track.dart';
import '../foundation/update_policy.dart';
import '../models/explicit_update_outcome.dart';
import '../models/release_info.dart';
import '../models/update_apply_outcome.dart';
import '../models/update_install_result.dart';
import '../models/update_resolution.dart';
import '../repositories/release_repository.dart';
import 'update_apply_service.dart';
import 'update_install_service.dart';

/// Coordinates an explicit, one-shot `sesori-bridge update`.
///
/// Unlike the background [UpdateService], this is a user-initiated action: it
/// overrides the background-only suppressors (`SESORI_NO_UPDATE`, CI) but still
/// requires the managed install. It resolves the latest release eligible for
/// the active track, decides what to do (plain vs `--force`, including the
/// internal→stable switch), then reuses [UpdateInstallService.stageUpdate] +
/// [UpdateApplyService.apply] to install it. It returns an
/// [ExplicitUpdateOutcome] as pure data — the command renders it and never the
/// service.
class ManualUpdateService({
  required final ReleaseRepository _releaseRepository,
  required final UpdateInstallService _updateInstallService,
  required final UpdateApplyService _updateApplyService,
  required final ReleaseTrack _track,
  required final String _installRoot,
  required final String _executablePath,
  required final String _managedExecutablePath,
}) {
  /// Runs the update once. When [force] is true, installs the latest eligible
  /// release for the active track regardless of the current version (a repair
  /// reinstall, or a downgrade onto the track); otherwise installs only a
  /// strictly-newer release and reports "already latest" or a track mismatch.
  Future<ExplicitUpdateOutcome> runUpdate({required bool force}) async {
    final ExplicitUpdateOutcome? gated = _gate();
    if (gated != null) {
      return gated;
    }

    final UpdateResolution resolution;
    try {
      resolution = await _releaseRepository.resolveUpdate();
    } on GitHubRateLimitException catch (error) {
      return ExplicitUpdateFailed(reason: _rateLimitReason(error), logPath: null);
    } on Object catch (error) {
      if (isTransientNetworkError(error)) {
        return ExplicitUpdateFailed(reason: "couldn't reach GitHub: $error", logPath: null);
      }
      return ExplicitUpdateFailed(reason: error.toString(), logPath: null);
    }

    final latest = resolution.latest;
    if (latest == null) {
      return ExplicitUpdateNoEligibleRelease(track: _track);
    }

    final release = latest.release;
    final latestVersion = latest.version;
    final SemanticVersion current = resolution.currentVersion;
    final int comparison = latestVersion.compareTo(current);

    if (!force) {
      if (comparison > 0) {
        return await _stageAndApply(release: release, fromVersion: current, kind: UpdateAppliedKind.upgrade);
      }
      if (comparison == 0) {
        return ExplicitUpdateAlreadyLatest(version: current.toString(), track: _track);
      }
      // comparison < 0: the running build is not the latest published build for
      // the track. Either it is off-track (e.g. an `-internal.*` build while the
      // track is stable), or it is "ahead" of the latest published release (a
      // copied dev/QA build, or a release that was yanked). A plain update can't
      // reach the published latest — only `--force` can — so point the user at
      // it rather than misreporting "already latest".
      return ExplicitUpdateTrackMismatch(
        currentVersion: current.toString(),
        latestVersion: latestVersion.toString(),
        track: _track,
      );
    }

    return await _stageAndApply(
      release: release,
      fromVersion: current,
      kind: comparison > 0
          ? UpdateAppliedKind.upgrade
          : comparison == 0
          ? UpdateAppliedKind.reinstall
          : UpdateAppliedKind.downgrade,
    );
  }

  /// Refuses to run anywhere but the managed install. An explicit command
  /// overrides the background-only suppressors, but it cannot update an npm
  /// payload run directly or a non-managed binary.
  ExplicitUpdateOutcome? _gate() {
    final String? npmMessage = unsupportedPackageRuntimeMessage(
      executablePath: _executablePath,
      managedExecutablePath: _managedExecutablePath,
    );
    if (npmMessage != null) {
      return ExplicitUpdateNpmDirect(message: npmMessage);
    }
    if (!isManagedInstall(
      executablePath: _executablePath,
      managedExecutablePath: _managedExecutablePath,
    )) {
      return ExplicitUpdateNotManaged(executablePath: _executablePath);
    }
    return null;
  }

  Future<ExplicitUpdateOutcome> _stageAndApply({
    required ReleaseInfo release,
    required SemanticVersion fromVersion,
    required UpdateAppliedKind kind,
  }) async {
    final UpdateInstallResult staged;
    try {
      staged = await _updateInstallService.stageUpdate(release: release, installRoot: _installRoot);
    } on Object catch (error) {
      return ExplicitUpdateFailed(reason: error.toString(), logPath: null);
    }

    switch (staged) {
      case UpdateInstallStageFailed(:final result):
        return ExplicitUpdateFailed(reason: result.userFacingReason, logPath: null);
      case UpdateInstallStaged(:final stagingPath):
        final UpdateApplyOutcome applyOutcome;
        try {
          applyOutcome = await _updateApplyService.apply(release: release, stagingPath: stagingPath);
        } on Object catch (error) {
          return ExplicitUpdateFailed(reason: error.toString(), logPath: null);
        }

        switch (applyOutcome) {
          case UpdateApplied(:final version):
            return ExplicitUpdateApplied(
              fromVersion: fromVersion.toString(),
              toVersion: version,
              kind: kind,
              track: _track,
            );
          case UpdateApplyLockBusy():
            return const ExplicitUpdateLockBusy();
          case UpdateApplyFailed(:final reason, :final logPath):
            return ExplicitUpdateFailed(reason: reason, logPath: logPath);
        }
    }
  }

  String _rateLimitReason(GitHubRateLimitException error) {
    if (error.authenticated) {
      return 'GitHub API rate limit reached for the authenticated token; try again shortly';
    }
    return 'GitHub API rate limit reached; set GITHUB_TOKEN (or GH_TOKEN) to raise the '
        '60/hour limit to 5000/hour, or try again later';
  }
}
