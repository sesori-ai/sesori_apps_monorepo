import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Console, Log;

import '../foundation/update_lock.dart';
import '../foundation/update_message_formatter.dart';
import '../models/update_attempt.dart';
import '../repositories/update_attempt_repository.dart';
import '../repositories/update_installation_repository.dart';
import '../repositories/update_log_repository.dart';

/// Startup-only reconciliation of the persisted [UpdateAttempt].
///
/// Runs once, early, on every launch: confirms a pending activation, reports an
/// interrupted (crashed) apply, surfaces a prior failure, sweeps residue, and
/// clears the record. Fast and local — it never touches the network.
class UpdateReconciliationService {
  UpdateReconciliationService({
    required UpdateAttemptRepository attemptRepository,
    required UpdateLogRepository logRepository,
    required UpdateInstallationRepository installationRepository,
    required UpdateMessageFormatter messageFormatter,
    required UpdateLock updateLock,
    required String currentVersion,
    required String installRoot,
  }) : _attemptRepository = attemptRepository,
       _logRepository = logRepository,
       _installationRepository = installationRepository,
       _messageFormatter = messageFormatter,
       _updateLock = updateLock,
       _currentVersion = currentVersion,
       _installRoot = installRoot;

  final UpdateAttemptRepository _attemptRepository;
  final UpdateLogRepository _logRepository;
  final UpdateInstallationRepository _installationRepository;
  final UpdateMessageFormatter _messageFormatter;
  final UpdateLock _updateLock;
  final String _currentVersion;
  final String _installRoot;

  @visibleForTesting
  void Function(String message) emitMessage = Console.message;

  @visibleForTesting
  void Function(String message) emitError = Console.error;

  @visibleForTesting
  void Function(String message) logWarning = Log.w;

  /// Reconciliation is best-effort startup maintenance. It runs entirely under
  /// the cross-process update lock because it executes BEFORE single-live-bridge
  /// enforcement: another bridge may start an apply (writing a new attempt
  /// record and creating `.old`/`.rollback` residue) between our read and our
  /// clear/sweep. Taking the lock means we never read a stale record and then
  /// delete a newer one, nor sweep residue an applying bridge still needs. If
  /// the lock is held, that bridge owns the in-flight state and reconciles on
  /// its own next launch.
  Future<void> reconcile() async {
    try {
      await _updateLock.locked<void>(
        lockFile: File(p.join(_installRoot, '.update.lock')),
        onLockAcquired: _reconcileLocked,
        onLockRejected: (LockAcquireResult result) async {
          switch (result) {
            case LockAcquireResult.alreadyLocked:
              logWarning('Skipping update reconciliation — the update lock is held by another process.');
            case LockAcquireResult.permissionDenied:
              // A stale/root-owned `.update.lock` the user cannot access is not
              // benign contention — it blocks every future update. Log it
              // distinctly so reconciliation does not mask it as "held by another
              // process"; the apply path surfaces full guidance when an update is
              // actually attempted.
              logWarning('Skipping update reconciliation — the update lock is not accessible (check ownership of .update.lock).');
            case LockAcquireResult.acquired:
              break; // never delivered to onLockRejected
          }
        },
        shouldReleaseLock: (_) => true,
      );
    } on Object catch (error) {
      logWarning('Update reconciliation failed: $error');
    }
  }

  /// The locked body: every step is isolated so a single I/O failure can
  /// neither abort the remaining cleanup nor hard-fail bridge startup.
  Future<void> _reconcileLocked() async {
    UpdateAttempt? attempt;
    try {
      attempt = await _attemptRepository.readAttempt();
    } on Object catch (error) {
      logWarning('Failed to read the update attempt record: $error');
    }

    if (attempt != null) {
      try {
        await _reconcileAttempt(attempt: attempt);
      } on Object catch (error) {
        logWarning('Failed to reconcile the update attempt: $error');
      }
    }

    try {
      await _installationRepository.sweepResidue(installRoot: _installRoot);
    } on Object catch (error) {
      logWarning('Failed to sweep update residue: $error');
    }

    if (attempt != null) {
      try {
        await _attemptRepository.clearAttempt();
      } on Object catch (error) {
        logWarning('Failed to clear the update attempt record: $error');
      }
    }
  }

  Future<void> _reconcileAttempt({required UpdateAttempt attempt}) async {
    switch (attempt.status) {
      case UpdateAttemptStatus.appliedPendingActivation:
        await _confirmActivation(attempt: attempt);
      case UpdateAttemptStatus.inFlight:
        await _recoverInterrupted(attempt: attempt);
      case UpdateAttemptStatus.failed:
        // Surface the prior failure even if the process died before the in-run
        // `Console.error` was emitted, so the recovery guidance is never lost.
        await _logBestEffort(
          'Surfacing prior failed update attempt for ${attempt.toVersion}: '
          '${attempt.reason ?? 'unknown reason'}',
        );
        emitError(
          _messageFormatter.failureGuidance(
            toVersion: attempt.toVersion,
            reason: attempt.reason ?? 'a previous update failed',
            logPath: _logRepository.logPath,
          ),
        );
    }
  }

  Future<void> _confirmActivation({required UpdateAttempt attempt}) async {
    // `appliedPendingActivation` is only recorded after BOTH the binary and lib
    // swap completed, so a version match here means the update truly took.
    if (_currentVersion == attempt.toVersion) {
      // Idempotently ensure the managed-runtime manifest reflects the activated
      // version before clearing the record. The apply path bumps it, but if the
      // bridge crashed between the status write and that bump, the manifest is
      // still stale here — and confirmation clears the only record, so a later
      // older `npx` could otherwise reinstall/downgrade the swapped runtime.
      // Best-effort: a failure only risks a later npm re-install, not activation.
      try {
        await _installationRepository.recordManagedVersion(
          installRoot: _installRoot,
          version: attempt.toVersion,
        );
      } on Object catch (error) {
        logWarning('Failed to bump the managed runtime manifest on activation confirm: $error');
      }
      await _logBestEffort('Activation confirmed: now running ${attempt.toVersion}.');
      emitMessage(_messageFormatter.activated(toVersion: attempt.toVersion));
      return;
    }

    await _logBestEffort('Activation mismatch: expected ${attempt.toVersion} but running $_currentVersion.');
    emitError(
      _messageFormatter.failureGuidance(
        toVersion: attempt.toVersion,
        reason: 'the updated binary did not take effect (still running $_currentVersion)',
        logPath: _logRepository.logPath,
      ),
    );
  }

  Future<void> _recoverInterrupted({required UpdateAttempt attempt}) async {
    // The apply was interrupted mid-swap. Even when the running version already
    // matches the target, we can't prove the lib swap finished before the crash
    // (the binary may have landed first), so we never claim a clean success
    // from the version alone — surface it as a possibly-incomplete update.
    await _logBestEffort(
      'Apply of ${attempt.toVersion} was interrupted mid-swap; running $_currentVersion.',
    );
    emitError(
      _messageFormatter.failureGuidance(
        toVersion: attempt.toVersion,
        reason: 'a previous update was interrupted and may be incomplete',
        logPath: _logRepository.logPath,
      ),
    );
  }

  /// Logging the reconciliation outcome must never suppress the user-facing
  /// message that follows it (e.g. an unwritable install root).
  Future<void> _logBestEffort(String message) async {
    try {
      await _logRepository.log(message: message);
    } on Object catch (error) {
      logWarning('Failed to write the update log: $error');
    }
  }
}
