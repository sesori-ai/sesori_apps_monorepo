import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/foundation/filesystem_cleaner.dart';
import 'package:sesori_bridge/src/updater/foundation/update_lock.dart';
import 'package:sesori_bridge/src/updater/foundation/update_message_formatter.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
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
}

class _FakeAttemptRepository implements UpdateAttemptRepository {
  final List<UpdateAttempt> saved = <UpdateAttempt>[];
  bool cleared = false;

  @override
  Future<UpdateAttempt?> readAttempt() async => saved.isEmpty ? null : saved.last;

  @override
  Future<void> saveAttempt({required UpdateAttempt attempt}) async => saved.add(attempt);

  @override
  Future<void> clearAttempt() async => cleared = true;
}

class _FakeLogRepository implements UpdateLogRepository {
  final List<String> messages = <String>[];

  @override
  String get logPath => '/tmp/.sesori-bridge-update.log';

  @override
  Future<void> logAttemptHeader({required String fromVersion, required String toVersion}) async {
    messages.add('header $fromVersion->$toVersion');
  }

  @override
  Future<void> log({required String message}) async => messages.add(message);
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
  late List<String> infoMessages;
  late List<String> errorMessages;
  late List<String> warnings;

  UpdateApplyService buildService() {
    final service = UpdateApplyService(
      installationRepository: installation,
      attemptRepository: attempts,
      logRepository: logs,
      updateLock: lock,
      messageFormatter: const UpdateMessageFormatter(),
      filesystemCleaner: const FilesystemCleaner(),
      clock: Clock.fixed(DateTime.utc(2026, 6, 17)),
      currentVersion: '1.0.0',
      installRoot: installRoot.path,
    );
    service.emitMessage = infoMessages.add;
    service.emitError = errorMessages.add;
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
    infoMessages = <String>[];
    errorMessages = <String>[];
    warnings = <String>[];
  });

  tearDown(() async {
    if (installRoot.existsSync()) {
      await installRoot.delete(recursive: true);
    }
  });

  test('successful apply records pending activation and reports it', () async {
    final service = buildService();

    final applied = await service.apply(release: _release(), stagingPath: stagingPath);

    expect(applied, isTrue);
    expect(installation.applyCount, 1);
    expect(attempts.saved.first.status, UpdateAttemptStatus.inFlight);
    expect(attempts.saved.last.status, UpdateAttemptStatus.appliedPendingActivation);
    expect(attempts.saved.last.stage, UpdateStage.activated);
    expect(infoMessages.single, contains('2.0.0'));
    expect(errorMessages, isEmpty);
    // The staging directory is cleaned after a successful apply.
    expect(Directory(stagingPath).existsSync(), isFalse);
  });

  test('failed swap records a failure and surfaces guidance', () async {
    installation.applyError = StateError('disk full');
    final service = buildService();

    final applied = await service.apply(release: _release(), stagingPath: stagingPath);

    expect(applied, isFalse);
    expect(attempts.saved.first.status, UpdateAttemptStatus.inFlight);
    expect(attempts.saved.last.status, UpdateAttemptStatus.failed);
    expect(attempts.saved.last.reason, contains('disk full'));
    expect(errorMessages.single, contains('https://sesori.com/'));
    expect(infoMessages, isEmpty);
  });

  test('lock contention is benign: no apply, a warning, no attempt record', () async {
    lock.outcome = LockAcquireResult.alreadyLocked;
    final service = buildService();

    final applied = await service.apply(release: _release(), stagingPath: stagingPath);

    expect(applied, isFalse);
    expect(installation.applyCount, 0);
    expect(attempts.saved, isEmpty);
    expect(warnings, hasLength(1));
    expect(errorMessages, isEmpty);
  });
}
