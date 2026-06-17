import 'dart:io';

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Console, Log;

import '../foundation/filesystem_cleaner.dart';
import '../foundation/update_lock.dart';
import '../foundation/update_message_formatter.dart';
import '../models/release_info.dart';
import '../models/update_attempt.dart';
import '../repositories/update_attempt_repository.dart';
import '../repositories/update_installation_repository.dart';
import '../repositories/update_log_repository.dart';

/// The shared in-place apply/rollback decision boundary.
///
/// Used by the periodic [UpdateService] to apply a freshly staged release. It
/// records a durable [UpdateAttempt] and an append-only log around the swap so a
/// failure is never silent, and surfaces user-facing messaging.
class UpdateApplyService {
  UpdateApplyService({
    required UpdateInstallationRepository installationRepository,
    required UpdateAttemptRepository attemptRepository,
    required UpdateLogRepository logRepository,
    required UpdateLock updateLock,
    required UpdateMessageFormatter messageFormatter,
    required FilesystemCleaner filesystemCleaner,
    required Clock clock,
    required String currentVersion,
    required String installRoot,
  }) : _installationRepository = installationRepository,
       _attemptRepository = attemptRepository,
       _logRepository = logRepository,
       _updateLock = updateLock,
       _messageFormatter = messageFormatter,
       _filesystemCleaner = filesystemCleaner,
       _clock = clock,
       _currentVersion = currentVersion,
       _installRoot = installRoot;

  final UpdateInstallationRepository _installationRepository;
  final UpdateAttemptRepository _attemptRepository;
  final UpdateLogRepository _logRepository;
  final UpdateLock _updateLock;
  final UpdateMessageFormatter _messageFormatter;
  final FilesystemCleaner _filesystemCleaner;
  final Clock _clock;
  final String _currentVersion;
  final String _installRoot;

  @visibleForTesting
  void Function(String message) emitMessage = Console.message;

  @visibleForTesting
  void Function(String message) emitError = Console.error;

  @visibleForTesting
  void Function(String message) logWarning = Log.w;

  /// Applies the staged payload at [stagingPath] in place, under the
  /// cross-process update lock. Returns `true` when the swap is staged for
  /// activation, `false` on any benign skip or genuine failure (both reported).
  Future<bool> apply({required ReleaseInfo release, required String stagingPath}) {
    return _updateLock.locked<bool>(
      lockFile: File(p.join(_installRoot, '.update.lock')),
      onLockAcquired: () => _applyLocked(release: release, stagingPath: stagingPath),
      onLockRejected: (LockAcquireResult result) async {
        switch (result) {
          case LockAcquireResult.alreadyLocked:
            // Another bridge is applying — benign; the next cycle retries.
            logWarning('Skipping in-place update to ${release.version}: another update is in progress');
          case LockAcquireResult.permissionDenied:
            // A stale/root-owned `.update.lock` the user can't read or delete
            // blocks every future update — surface it instead of silently
            // re-downloading and warning forever.
            await _reportLockPermissionFailure(release: release);
          case LockAcquireResult.acquired:
            break; // never delivered to onLockRejected
        }
        return false;
      },
      shouldReleaseLock: (_) => true,
    );
  }

  Future<void> _reportLockPermissionFailure({required ReleaseInfo release}) async {
    try {
      await _logRepository.log(
        message: 'Update lock permission denied applying ${release.version} (check ownership of .update.lock)',
      );
    } on Object catch (error) {
      logWarning('Failed to log update lock failure: $error');
    }
    emitError(
      _messageFormatter.failureGuidance(
        toVersion: release.version,
        reason: 'the update lock could not be acquired (permission denied on .update.lock)',
        logPath: _logRepository.logPath,
      ),
    );
  }

  Future<bool> _applyLocked({required ReleaseInfo release, required String stagingPath}) async {
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
    // apply failure and must surface to the user + durable log, never throw out
    // of apply() into the caller's onError path.
    try {
      await _logRepository.logAttemptHeader(fromVersion: _currentVersion, toVersion: release.version);
      await _attemptRepository.saveAttempt(attempt: attempt);
      await _logRepository.log(message: 'Applying in-place swap from staging: $stagingPath');
      await _installationRepository.applyInPlace(installRoot: _installRoot, stagingPath: stagingPath);
    } on Object catch (error, stackTrace) {
      await _reportSwapFailure(attempt: attempt, release: release, error: error, stackTrace: stackTrace);
      await _cleanupStaging(stagingPath: stagingPath);
      return false;
    }

    await _recordPendingActivation(attempt: attempt, release: release);
    await _cleanupStaging(stagingPath: stagingPath);
    return true;
  }

  Future<void> _reportSwapFailure({
    required UpdateAttempt attempt,
    required ReleaseInfo release,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    // Recording the failure is itself best-effort — the repository whose write
    // just failed may fail again — but the user-facing guidance always runs.
    try {
      await _attemptRepository.saveAttempt(
        attempt: attempt.copyWith(status: UpdateAttemptStatus.failed, reason: error.toString()),
      );
      await _logRepository.log(message: 'Swap failed: $error\n$stackTrace');
    } on Object catch (recordError) {
      logWarning('Failed to record the update failure: $recordError');
    }
    emitError(
      _messageFormatter.failureGuidance(
        toVersion: release.version,
        reason: error.toString(),
        logPath: _logRepository.logPath,
      ),
    );
  }

  Future<void> _recordPendingActivation({
    required UpdateAttempt attempt,
    required ReleaseInfo release,
  }) async {
    // Bump the managed-runtime manifest so the npm bootstrap sees the new
    // version and does not clobber/downgrade the freshly swapped binary on the
    // next `npx`. Best-effort: the swap already landed, so a manifest write
    // failure only risks a later npm re-install, not the update itself.
    try {
      await _installationRepository.recordManagedVersion(installRoot: _installRoot, version: release.version);
    } on Object catch (manifestError) {
      logWarning('Failed to update the managed runtime manifest: $manifestError');
    }

    // Best-effort: the swap already landed on disk, so even if the record write
    // fails the next launch confirms activation via the running version. The
    // success message always runs.
    try {
      await _attemptRepository.saveAttempt(
        attempt: attempt.copyWith(stage: UpdateStage.activated, status: UpdateAttemptStatus.appliedPendingActivation),
      );
      await _logRepository.log(message: 'Swap complete; ${release.version} pending activation on next launch.');
    } on Object catch (recordError) {
      logWarning('Failed to record the pending activation: $recordError');
    }
    emitMessage(_messageFormatter.installedPendingActivation(toVersion: release.version));
  }

  Future<void> _cleanupStaging({required String stagingPath}) {
    return _filesystemCleaner.delete(path: stagingPath, recursive: true);
  }
}
