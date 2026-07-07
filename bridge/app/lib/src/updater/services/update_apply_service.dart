import 'dart:io';

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../foundation/filesystem_cleaner.dart';
import '../foundation/update_lock.dart';
import '../models/release_info.dart';
import '../models/update_apply_outcome.dart';
import '../models/update_attempt.dart';
import '../repositories/update_attempt_repository.dart';
import '../repositories/update_installation_repository.dart';
import '../repositories/update_log_repository.dart';

/// The shared in-place apply/rollback boundary for a staged release.
///
/// It records a durable [UpdateAttempt] and an append-only log around the swap
/// so a failure is never silent, then returns an [UpdateApplyOutcome] describing
/// what happened. Presentation lives with the caller — this service never writes
/// to `Console`.
class UpdateApplyService {
  UpdateApplyService({
    required UpdateInstallationRepository installationRepository,
    required UpdateAttemptRepository attemptRepository,
    required UpdateLogRepository logRepository,
    required UpdateLock updateLock,
    required FilesystemCleaner filesystemCleaner,
    required Clock clock,
    required String currentVersion,
    required String installRoot,
  }) : _installationRepository = installationRepository,
       _attemptRepository = attemptRepository,
       _logRepository = logRepository,
       _updateLock = updateLock,
       _filesystemCleaner = filesystemCleaner,
       _clock = clock,
       _currentVersion = currentVersion,
       _installRoot = installRoot;

  final UpdateInstallationRepository _installationRepository;
  final UpdateAttemptRepository _attemptRepository;
  final UpdateLogRepository _logRepository;
  final UpdateLock _updateLock;
  final FilesystemCleaner _filesystemCleaner;
  final Clock _clock;
  final String _currentVersion;
  final String _installRoot;

  @visibleForTesting
  void Function(String message) logWarning = Log.w;

  /// Whether a successful apply can be chained with another in the same session
  /// before a restart activates it. Delegates to the platform applier: POSIX can
  /// clear the displaced backup of the still-running binary, Windows cannot until
  /// the next launch. The background updater consults this to decide whether to
  /// keep polling after an apply or wait for a restart.
  bool get supportsInSessionChaining => _installationRepository.supportsInSessionChaining;

  /// Applies the staged payload at [stagingPath] in place, under the
  /// cross-process update lock. Returns an [UpdateApplyOutcome] describing the
  /// result. The durable attempt record and the update log are written here, but
  /// no user-facing message is emitted — the caller presents the outcome.
  Future<UpdateApplyOutcome> apply({required ReleaseInfo release, required String stagingPath}) {
    return _updateLock.locked<UpdateApplyOutcome>(
      lockFile: File(p.join(_installRoot, '.update.lock')),
      staleLockMaxAge: UpdateLock.updateStaleLockMaxAge,
      onLockAcquired: () => _applyLocked(release: release, stagingPath: stagingPath),
      onLockRejected: (LockAcquireResult result) async {
        final UpdateApplyOutcome outcome;
        switch (result) {
          case LockAcquireResult.alreadyLocked:
            // Another bridge is applying — benign; the next cycle retries.
            logWarning('Skipping in-place update to ${release.version}: another update is in progress');
            outcome = const UpdateApplyLockBusy();
          case LockAcquireResult.permissionDenied:
            // A stale/root-owned `.update.lock` the user can't read or delete
            // blocks every future update — surface it instead of silently
            // re-downloading and warning forever.
            outcome = await _recordLockPermissionFailure(release: release);
          case LockAcquireResult.acquired:
            // Never delivered to onLockRejected.
            outcome = const UpdateApplyLockBusy();
        }
        // The swap never ran, so the staged payload we were handed is ours to
        // remove. Staging paths are per-stager, so this never deletes the
        // payload the lock-holding applier is consuming. Without it, a manual
        // update's per-process staging dir would accumulate on every attempt
        // made during a resident update or a stale lock.
        await _cleanupStaging(stagingPath: stagingPath);
        return outcome;
      },
      shouldReleaseLock: (_) => true,
    );
  }

  Future<UpdateApplyOutcome> _recordLockPermissionFailure({required ReleaseInfo release}) async {
    try {
      await _logRepository.log(
        message: 'Update lock permission denied applying ${release.version} (check ownership of .update.lock)',
      );
    } on Object catch (error) {
      logWarning('Failed to log update lock failure: $error');
    }
    return UpdateApplyFailed(
      reason: 'the update lock could not be acquired (permission denied on .update.lock)',
      logPath: _logRepository.logPath,
    );
  }

  Future<UpdateApplyOutcome> _applyLocked({required ReleaseInfo release, required String stagingPath}) async {
    final UpdateAttempt attempt = UpdateAttempt(
      fromVersion: _currentVersion,
      toVersion: release.version,
      startedAt: _clock.now(),
      stage: UpdateStage.swapping,
      status: UpdateAttemptStatus.inFlight,
      reason: null,
    );

    // The pre-apply record/log writes are guarded together with the swap: an
    // I/O failure there (e.g. an unwritable install root) is itself a genuine
    // apply failure and must be recorded and returned, never thrown out of
    // apply() into the caller's onError path.
    try {
      await _logRepository.logAttemptHeader(fromVersion: _currentVersion, toVersion: release.version);
      await _attemptRepository.saveAttempt(attempt: attempt);
      await _logRepository.log(message: 'Applying in-place swap from staging: $stagingPath');
      await _installationRepository.applyInPlace(installRoot: _installRoot, stagingPath: stagingPath);
    } on Object catch (error, stackTrace) {
      final UpdateApplyOutcome outcome = await _recordSwapFailure(
        attempt: attempt,
        release: release,
        error: error,
        stackTrace: stackTrace,
      );
      await _cleanupStaging(stagingPath: stagingPath);
      return outcome;
    }

    final bool durablyRecorded = await _recordPendingActivation(attempt: attempt, release: release);
    await _cleanupStaging(stagingPath: stagingPath);
    return UpdateApplied(version: release.version, durablyRecorded: durablyRecorded);
  }

  Future<UpdateApplyOutcome> _recordSwapFailure({
    required UpdateAttempt attempt,
    required ReleaseInfo release,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    // Recording the failure is itself best-effort — the repository whose write
    // just failed may fail again — but the returned outcome always carries the
    // cause for the caller to surface.
    try {
      await _attemptRepository.saveAttempt(
        attempt: attempt.copyWith(status: UpdateAttemptStatus.failed, reason: error.toString()),
      );
      await _logRepository.log(message: 'Swap failed: $error\n$stackTrace');
    } on Object catch (recordError) {
      logWarning('Failed to record the update failure: $recordError');
    }
    return UpdateApplyFailed(reason: error.toString(), logPath: _logRepository.logPath);
  }

  /// Records the post-swap bookkeeping and returns whether it fully succeeded,
  /// i.e. the managed-runtime manifest now names [release]. A false return means
  /// the manifest is still stale and the next launch depends on this version's
  /// `appliedPendingActivation` record to retry the bump — the caller must not
  /// let a chained apply overwrite that record before a restart reconciles it.
  Future<bool> _recordPendingActivation({
    required UpdateAttempt attempt,
    required ReleaseInfo release,
  }) async {
    // The swap already landed on disk, so these are post-swap bookkeeping
    // writes — best-effort, never fatal. The invariant to preserve is that the
    // durable attempt record is NEVER left at `inFlight` after a successful
    // swap: the next-launch reconciliation would otherwise treat a successful
    // update as interrupted and emit reinstall guidance, contradicting the
    // success the caller reports.
    var pendingActivationRecorded = false;
    try {
      await _attemptRepository.saveAttempt(
        attempt: attempt.copyWith(stage: UpdateStage.activated, status: UpdateAttemptStatus.appliedPendingActivation),
      );
      // Set the flag right after the durable STATUS write, before the incidental
      // log append, so a log failure doesn't misclassify a recorded activation.
      pendingActivationRecorded = true;
      await _logRepository.log(message: 'Swap complete; ${release.version} pending activation on next launch.');
    } on Object catch (recordError) {
      logWarning('Failed to record the pending activation: $recordError');
    }

    if (!pendingActivationRecorded) {
      // The activation-status write failed after a successful swap. Clear the
      // stale `inFlight` record so the next launch doesn't reconcile this
      // successful update as interrupted. (Deleting the record can succeed where
      // the write+rename did not.) Once it's cleared, the manifest bump below
      // can no longer diverge from an `inFlight` record.
      try {
        await _attemptRepository.clearAttempt();
      } on Object catch (clearError) {
        logWarning('Failed to clear the in-flight attempt after a status-write failure: $clearError');
      }
    }

    // Bump the managed-runtime manifest so the npm bootstrap sees the new
    // version and does not clobber/downgrade the freshly swapped binary on the
    // next `npx`. Safe to always attempt after a successful swap: the record is
    // now either `appliedPendingActivation` (confirmed next launch) or cleared,
    // so this never leaves a manifest claiming a version an `inFlight` record
    // contradicts. Best-effort: a failure only risks a later npm re-install.
    try {
      await _installationRepository.recordManagedVersion(installRoot: _installRoot, version: release.version);
    } on Object catch (manifestError) {
      logWarning('Failed to update the managed runtime manifest: $manifestError');
      return false;
    }

    // Fully persisted only when BOTH the durable activation status and the
    // manifest bump landed. If the status write failed above we cleared the
    // record, so the next launch cannot confirm-and-retry this version — it is
    // not safe to chain over it either.
    return pendingActivationRecorded;
  }

  Future<void> _cleanupStaging({required String stagingPath}) {
    return _filesystemCleaner.delete(path: stagingPath, recursive: true);
  }
}
