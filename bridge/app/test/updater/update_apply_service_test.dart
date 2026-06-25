import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/foundation/filesystem_cleaner.dart';
import 'package:sesori_bridge/src/updater/foundation/update_lock.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/models/update_apply_outcome.dart';
import 'package:sesori_bridge/src/updater/models/update_attempt.dart';
import 'package:sesori_bridge/src/updater/repositories/update_attempt_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_installation_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_log_repository.dart';
import 'package:sesori_bridge/src/updater/services/update_apply_service.dart';
import 'package:test/test.dart';

class _FakeInstallationRepository implements UpdateInstallationRepository {
  Object? applyError;
  int applyCount = 0;
  int sweepCount = 0;
  String? recordedVersion;

  @override
  Future<void> applyInPlace({required String installRoot, required String stagingPath}) async {
    applyCount++;
    if (applyError != null) {
      throw applyError!;
    }
  }

  @override
  Future<void> sweepResidue({required String installRoot}) async {
    sweepCount++;
  }

  @override
  Future<void> recordManagedVersion({required String installRoot, required String version}) async {
    recordedVersion = version;
  }
}

class _FakeAttemptRepository implements UpdateAttemptRepository {
  final List<UpdateAttempt> saved = <UpdateAttempt>[];
  bool cleared = false;

  /// When set, `saveAttempt` throws for an attempt with this status (used to
  /// simulate a durable-write failure on a specific transition).
  UpdateAttemptStatus? throwOnSaveStatus;

  @override
  Future<UpdateAttempt?> readAttempt() async => saved.isEmpty ? null : saved.last;

  @override
  Future<void> saveAttempt({required UpdateAttempt attempt}) async {
    if (attempt.status == throwOnSaveStatus) {
      throw StateError('attempt write failed');
    }
    saved.add(attempt);
  }

  @override
  Future<void> clearAttempt() async => cleared = true;
}

class _FakeLogRepository implements UpdateLogRepository {
  final List<String> messages = <String>[];

  /// When set, a `log` call whose message contains this substring throws,
  /// simulating an unwritable/rotated log file.
  String? throwOnMessageContaining;

  @override
  String get logPath => '/tmp/.sesori-bridge-update.log';

  @override
  Future<void> logAttemptHeader({required String fromVersion, required String toVersion}) async {
    messages.add('header $fromVersion->$toVersion');
  }

  @override
  Future<void> log({required String message}) async {
    final needle = throwOnMessageContaining;
    if (needle != null && message.contains(needle)) {
      throw const FileSystemException('log write failed');
    }
    messages.add(message);
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
    Duration? staleLockMaxAge,
  }) {
    if (outcome == LockAcquireResult.acquired) {
      return onLockAcquired();
    }
    return onLockRejected(outcome);
  }

  @override
  Future<bool> isProcessAlive({required int pidToCheck}) async => false;
}

ReleaseInfo _release() => ReleaseInfo(
  version: '2.0.0',
  assetUrl: 'https://example.com/bridge.tar.gz',
  checksumsUrl: 'https://example.com/checksums.txt',
  publishedAt: DateTime.utc(2026),
);

void main() {
  late Directory installRoot;
  late String stagingPath;
  late _FakeInstallationRepository installation;
  late _FakeAttemptRepository attempts;
  late _FakeLogRepository logs;
  late _FakeUpdateLock lock;
  late List<String> warnings;

  UpdateApplyService buildService() {
    final service = UpdateApplyService(
      installationRepository: installation,
      attemptRepository: attempts,
      logRepository: logs,
      updateLock: lock,
      filesystemCleaner: const FilesystemCleaner(),
      clock: Clock.fixed(DateTime.utc(2026, 6, 17)),
      currentVersion: '1.0.0',
      installRoot: installRoot.path,
    );
    service.logWarning = warnings.add;
    return service;
  }

  setUp(() async {
    installRoot = await Directory.systemTemp.createTemp('update-apply-service');
    stagingPath = p.join(installRoot.path, '.sesori-bridge-staging');
    Directory(stagingPath).createSync(recursive: true);
    installation = _FakeInstallationRepository();
    attempts = _FakeAttemptRepository();
    logs = _FakeLogRepository();
    lock = _FakeUpdateLock();
    warnings = <String>[];
  });

  tearDown(() async {
    if (installRoot.existsSync()) {
      await installRoot.delete(recursive: true);
    }
  });

  test('successful apply records pending activation and returns applied', () async {
    final service = buildService();

    final outcome = await service.apply(release: _release(), stagingPath: stagingPath);

    expect(outcome, isA<UpdateApplied>().having((o) => o.version, 'version', '2.0.0'));
    expect(installation.applyCount, 1);
    // The managed-runtime manifest is bumped so the npm bootstrap won't clobber
    // the freshly swapped binary.
    expect(installation.recordedVersion, '2.0.0');
    expect(attempts.saved.first.status, UpdateAttemptStatus.inFlight);
    expect(attempts.saved.last.status, UpdateAttemptStatus.appliedPendingActivation);
    expect(attempts.saved.last.stage, UpdateStage.activated);
    // The staging directory is cleaned after a successful apply.
    expect(Directory(stagingPath).existsSync(), isFalse);
  });

  test('pending-activation write failure clears the stale record and bumps the manifest', () async {
    attempts.throwOnSaveStatus = UpdateAttemptStatus.appliedPendingActivation;
    final service = buildService();

    final outcome = await service.apply(release: _release(), stagingPath: stagingPath);

    // The swap landed, so apply still succeeds; recording activation is
    // best-effort.
    expect(outcome, isA<UpdateApplied>());
    expect(installation.applyCount, 1);
    // The inFlight record could not be advanced to appliedPendingActivation, so
    // it is cleared — the next launch must not reconcile this successful update
    // as interrupted. With no inFlight record left, the manifest is bumped so
    // npm sees the new version.
    expect(attempts.cleared, isTrue);
    expect(installation.recordedVersion, '2.0.0');
    expect(warnings, contains(predicate<String>((w) => w.contains('pending activation'))));
  });

  test('a log-append failure after the status write still bumps the manifest', () async {
    // The durable activation status is written, but the trailing log append
    // fails. The manifest must still be bumped — otherwise .managed-runtime.json
    // stays stale and a later older npx could downgrade the swapped binary.
    logs.throwOnMessageContaining = 'pending activation on next launch';
    final service = buildService();

    final outcome = await service.apply(release: _release(), stagingPath: stagingPath);

    expect(outcome, isA<UpdateApplied>());
    expect(attempts.saved.last.status, UpdateAttemptStatus.appliedPendingActivation);
    expect(installation.recordedVersion, '2.0.0');
    expect(warnings, contains(predicate<String>((w) => w.contains('pending activation'))));
  });

  test('failed swap records a failure and returns it with the log path', () async {
    installation.applyError = StateError('disk full');
    final service = buildService();

    final outcome = await service.apply(release: _release(), stagingPath: stagingPath);

    expect(
      outcome,
      isA<UpdateApplyFailed>()
          .having((o) => o.reason, 'reason', contains('disk full'))
          .having((o) => o.logPath, 'logPath', logs.logPath),
    );
    expect(attempts.saved.first.status, UpdateAttemptStatus.inFlight);
    expect(attempts.saved.last.status, UpdateAttemptStatus.failed);
    expect(attempts.saved.last.reason, contains('disk full'));
  });

  test('lock contention is benign: no apply, a warning, no attempt record', () async {
    lock.outcome = LockAcquireResult.alreadyLocked;
    final service = buildService();

    final outcome = await service.apply(release: _release(), stagingPath: stagingPath);

    expect(outcome, isA<UpdateApplyLockBusy>());
    expect(installation.applyCount, 0);
    expect(attempts.saved, isEmpty);
    expect(warnings, hasLength(1));
    // The swap never ran, so the staged payload is cleaned up rather than left
    // to accumulate (important for the per-process manual staging dirs).
    expect(Directory(stagingPath).existsSync(), isFalse);
  });

  test('lock permission denied surfaces a failure', () async {
    lock.outcome = LockAcquireResult.permissionDenied;
    final service = buildService();

    final outcome = await service.apply(release: _release(), stagingPath: stagingPath);

    expect(
      outcome,
      isA<UpdateApplyFailed>().having((o) => o.reason, 'reason', contains('permission denied')),
    );
    expect(installation.applyCount, 0);
    expect(Directory(stagingPath).existsSync(), isFalse);
  });
}
