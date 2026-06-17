import 'dart:io';

import 'package:sesori_bridge/src/updater/foundation/update_lock.dart';
import 'package:sesori_bridge/src/updater/foundation/update_message_formatter.dart';
import 'package:sesori_bridge/src/updater/models/update_attempt.dart';
import 'package:sesori_bridge/src/updater/repositories/update_attempt_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_installation_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_log_repository.dart';
import 'package:sesori_bridge/src/updater/services/update_reconciliation_service.dart';
import 'package:test/test.dart';

class _FakeAttemptRepository implements UpdateAttemptRepository {
  UpdateAttempt? stored;
  bool cleared = false;

  @override
  Future<UpdateAttempt?> readAttempt() async => stored;

  @override
  Future<void> saveAttempt({required UpdateAttempt attempt}) async => stored = attempt;

  @override
  Future<void> clearAttempt() async => cleared = true;
}

class _FakeLogRepository implements UpdateLogRepository {
  final List<String> messages = <String>[];

  @override
  String get logPath => '/tmp/.sesori-bridge-update.log';

  @override
  Future<void> logAttemptHeader({required String fromVersion, required String toVersion}) async {}

  @override
  Future<void> log({required String message}) async => messages.add(message);
}

class _FakeInstallationRepository implements UpdateInstallationRepository {
  int sweepCount = 0;

  @override
  Future<void> applyInPlace({required String installRoot, required String stagingPath}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> sweepResidue({required String installRoot}) async => sweepCount++;

  @override
  Future<void> recordManagedVersion({required String installRoot, required String version}) async {
    throw UnimplementedError();
  }
}

class _FakeUpdateLock implements UpdateLock {
  LockAcquireResult outcome = LockAcquireResult.acquired;

  @override
  Future<T> locked<T>({
    required File lockFile,
    required Future<T> Function() onLockAcquired,
    required Future<T> Function(LockAcquireResult result) onLockRejected,
    required bool Function(T value) shouldReleaseLock,
  }) {
    if (outcome == LockAcquireResult.acquired) {
      return onLockAcquired();
    }
    return onLockRejected(outcome);
  }

  @override
  Future<bool> isProcessAlive({required int pidToCheck}) async => false;
}

UpdateAttempt _attempt({
  required UpdateAttemptStatus status,
  String toVersion = '2.0.0',
  String? reason,
}) {
  return UpdateAttempt(
    fromVersion: '1.0.0',
    toVersion: toVersion,
    startedAt: DateTime.utc(2026, 6, 17),
    stage: UpdateStage.swapping,
    status: status,
    reason: reason,
  );
}

void main() {
  late _FakeAttemptRepository attempts;
  late _FakeLogRepository logs;
  late _FakeInstallationRepository installation;
  late _FakeUpdateLock lock;
  late List<String> infoMessages;
  late List<String> errorMessages;

  UpdateReconciliationService buildService({required String currentVersion}) {
    final service = UpdateReconciliationService(
      attemptRepository: attempts,
      logRepository: logs,
      installationRepository: installation,
      messageFormatter: const UpdateMessageFormatter(),
      updateLock: lock,
      currentVersion: currentVersion,
      installRoot: '/tmp/install',
    );
    service.emitMessage = infoMessages.add;
    service.emitError = errorMessages.add;
    return service;
  }

  setUp(() {
    attempts = _FakeAttemptRepository();
    logs = _FakeLogRepository();
    installation = _FakeInstallationRepository();
    lock = _FakeUpdateLock();
    infoMessages = <String>[];
    errorMessages = <String>[];
  });

  test('no attempt: sweeps residue, nothing reported, nothing cleared', () async {
    await buildService(currentVersion: '1.0.0').reconcile();

    expect(installation.sweepCount, 1);
    expect(infoMessages, isEmpty);
    expect(errorMessages, isEmpty);
    expect(attempts.cleared, isFalse);
  });

  test('residue sweep is skipped when the update lock is held by another process', () async {
    lock.outcome = LockAcquireResult.alreadyLocked;

    await buildService(currentVersion: '1.0.0').reconcile();

    expect(installation.sweepCount, 0);
  });

  test('pending activation that matches the running version is confirmed', () async {
    attempts.stored = _attempt(status: UpdateAttemptStatus.appliedPendingActivation);

    await buildService(currentVersion: '2.0.0').reconcile();

    expect(infoMessages.single, contains('Updated to 2.0.0'));
    expect(errorMessages, isEmpty);
    expect(attempts.cleared, isTrue);
    expect(installation.sweepCount, 1);
  });

  test('pending activation that did not take effect is reported as a failure', () async {
    attempts.stored = _attempt(status: UpdateAttemptStatus.appliedPendingActivation);

    await buildService(currentVersion: '1.0.0').reconcile();

    expect(infoMessages, isEmpty);
    expect(errorMessages.single, contains('https://sesori.com/'));
    expect(attempts.cleared, isTrue);
  });

  test('interrupted apply is reported as possibly incomplete even when the version matches', () async {
    attempts.stored = _attempt(status: UpdateAttemptStatus.inFlight);

    await buildService(currentVersion: '2.0.0').reconcile();

    // We never claim a clean success from the version alone for an interrupted
    // swap — the lib swap may not have finished before the crash.
    expect(infoMessages, isEmpty);
    expect(errorMessages.single, contains('interrupted'));
    expect(attempts.cleared, isTrue);
  });

  test('interrupted apply that did not land is reported as a failure', () async {
    attempts.stored = _attempt(status: UpdateAttemptStatus.inFlight);

    await buildService(currentVersion: '1.0.0').reconcile();

    expect(errorMessages.single, contains('interrupted'));
    expect(attempts.cleared, isTrue);
  });

  test('a prior failed attempt is surfaced and cleared', () async {
    attempts.stored = _attempt(status: UpdateAttemptStatus.failed, reason: 'permission denied');

    await buildService(currentVersion: '1.0.0').reconcile();

    expect(infoMessages, isEmpty);
    expect(errorMessages.single, contains('permission denied'));
    expect(attempts.cleared, isTrue);
    expect(installation.sweepCount, 1);
  });
}
