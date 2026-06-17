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
        // Another bridge is applying, or we lack permission — both benign for a
        // best-effort updater. Stays quiet in Log; reconcile/next cycle retries.
        logWarning('Skipping in-place update to ${release.version}: ${result.name}');
        return false;
      },
      shouldReleaseLock: (_) => true,
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

    await _logRepository.logAttemptHeader(fromVersion: _currentVersion, toVersion: release.version);
    await _attemptRepository.saveAttempt(attempt: attempt);
    await _logRepository.log(message: 'Applying in-place swap from staging: $stagingPath');

    try {
      await _installationRepository.applyInPlace(installRoot: _installRoot, stagingPath: stagingPath);
    } on Object catch (error, stackTrace) {
      await _attemptRepository.saveAttempt(
        attempt: attempt.copyWith(status: UpdateAttemptStatus.failed, reason: error.toString()),
      );
      await _logRepository.log(message: 'Swap failed: $error\n$stackTrace');
      emitError(
        _messageFormatter.failureGuidance(
          toVersion: release.version,
          reason: error.toString(),
          logPath: _logRepository.logPath,
        ),
      );
      await _cleanupStaging(stagingPath: stagingPath);
      return false;
    }

    await _attemptRepository.saveAttempt(
      attempt: attempt.copyWith(stage: UpdateStage.activated, status: UpdateAttemptStatus.appliedPendingActivation),
    );
    await _logRepository.log(message: 'Swap complete; ${release.version} pending activation on next launch.');
    emitMessage(_messageFormatter.installedPendingActivation(toVersion: release.version));
    await _cleanupStaging(stagingPath: stagingPath);
    return true;
  }

  Future<void> _cleanupStaging({required String stagingPath}) {
    return _filesystemCleaner.delete(path: stagingPath, recursive: true);
  }
}
