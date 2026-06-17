import 'package:meta/meta.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Console, Log;

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
    required String currentVersion,
    required String installRoot,
  }) : _attemptRepository = attemptRepository,
       _logRepository = logRepository,
       _installationRepository = installationRepository,
       _messageFormatter = messageFormatter,
       _currentVersion = currentVersion,
       _installRoot = installRoot;

  final UpdateAttemptRepository _attemptRepository;
  final UpdateLogRepository _logRepository;
  final UpdateInstallationRepository _installationRepository;
  final UpdateMessageFormatter _messageFormatter;
  final String _currentVersion;
  final String _installRoot;

  @visibleForTesting
  void Function(String message) emitMessage = Console.message;

  @visibleForTesting
  void Function(String message) emitError = Console.error;

  @visibleForTesting
  void Function(String message) logWarning = Log.w;

  Future<void> reconcile() async {
    UpdateAttempt? attempt;
    try {
      attempt = await _attemptRepository.readAttempt();
    } on Object catch (error) {
      logWarning('Failed to read the update attempt record: $error');
    }

    if (attempt != null) {
      await _reconcileAttempt(attempt: attempt);
    }

    await _installationRepository.sweepResidue(installRoot: _installRoot);

    if (attempt != null) {
      await _attemptRepository.clearAttempt();
    }
  }

  Future<void> _reconcileAttempt({required UpdateAttempt attempt}) async {
    switch (attempt.status) {
      case UpdateAttemptStatus.appliedPendingActivation:
        await _confirmActivation(attempt: attempt);
      case UpdateAttemptStatus.inFlight:
        await _recoverInterrupted(attempt: attempt);
      case UpdateAttemptStatus.failed:
        // The failure was already surfaced when it happened; just record the
        // cleanup so the durable log keeps a continuous trail.
        await _logRepository.log(
          message: 'Clearing prior failed attempt for ${attempt.toVersion}: ${attempt.reason ?? 'unknown reason'}',
        );
    }
  }

  Future<void> _confirmActivation({required UpdateAttempt attempt}) async {
    if (_currentVersion == attempt.toVersion) {
      await _logRepository.log(message: 'Activation confirmed: now running ${attempt.toVersion}.');
      emitMessage(_messageFormatter.activated(toVersion: attempt.toVersion));
      return;
    }

    await _logRepository.log(
      message: 'Activation mismatch: expected ${attempt.toVersion} but running $_currentVersion.',
    );
    emitError(
      _messageFormatter.failureGuidance(
        toVersion: attempt.toVersion,
        reason: 'the updated binary did not take effect (still running $_currentVersion)',
        logPath: _logRepository.logPath,
      ),
    );
  }

  Future<void> _recoverInterrupted({required UpdateAttempt attempt}) async {
    if (_currentVersion == attempt.toVersion) {
      // The swap finished on disk before the crash; the new version is live.
      await _logRepository.log(
        message: 'Apply was interrupted but ${attempt.toVersion} is now active.',
      );
      emitMessage(_messageFormatter.activated(toVersion: attempt.toVersion));
      return;
    }

    await _logRepository.log(
      message: 'Apply interrupted mid-swap; recovered to $_currentVersion (target was ${attempt.toVersion}).',
    );
    emitError(
      _messageFormatter.failureGuidance(
        toVersion: attempt.toVersion,
        reason: 'a previous update was interrupted before it completed',
        logPath: _logRepository.logPath,
      ),
    );
  }
}
