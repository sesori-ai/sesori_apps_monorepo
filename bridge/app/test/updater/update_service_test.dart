import 'package:fake_async/fake_async.dart';
import 'package:sesori_bridge/src/updater/foundation/github_rate_limit_exception.dart';
import 'package:sesori_bridge/src/updater/foundation/update_message_formatter.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/models/update_apply_outcome.dart';
import 'package:sesori_bridge/src/updater/models/update_install_result.dart';
import 'package:sesori_bridge/src/updater/models/update_resolution.dart';
import 'package:sesori_bridge/src/updater/models/update_result.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_log_repository.dart';
import 'package:sesori_bridge/src/updater/services/update_apply_service.dart';
import 'package:sesori_bridge/src/updater/services/update_install_service.dart';
import 'package:sesori_bridge/src/updater/services/update_service.dart';
import 'package:test/test.dart';

const String _managedPath = '/usr/local/bin/sesori-bridge';

class _FakeReleaseRepository implements ReleaseRepository {
  int checkCount = 0;
  Future<ReleaseInfo?> Function()? onCheck;
  final List<String> advancedBaselines = <String>[];

  @override
  Future<ReleaseInfo?> checkForNewerRelease() async {
    checkCount++;
    return onCheck == null ? null : onCheck!();
  }

  @override
  void advanceBaselineTo({required String version}) => advancedBaselines.add(version);

  @override
  Future<UpdateResolution> resolveUpdate() => throw UnimplementedError();
}

class _FakeInstallService implements UpdateInstallService {
  UpdateInstallResult result = const UpdateInstallResult.staged(stagingPath: '/tmp/staging');
  int stageCount = 0;

  @override
  Future<UpdateInstallResult> stageUpdate({required ReleaseInfo release, required String installRoot}) async {
    stageCount++;
    return result;
  }
}

class _FakeApplyService implements UpdateApplyService {
  final List<String> appliedVersions = <String>[];
  UpdateApplyOutcome Function(ReleaseInfo release)? onApply;

  @override
  bool supportsInSessionChaining = true;

  @override
  void Function(String message) logWarning = (_) {};

  @override
  Future<UpdateApplyOutcome> apply({required ReleaseInfo release, required String stagingPath}) async {
    appliedVersions.add(release.version);
    return onApply?.call(release) ?? UpdateApplied(version: release.version);
  }
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

ReleaseInfo _release({String version = '2.0.0'}) => ReleaseInfo(
  version: version,
  assetUrl: 'https://example.com/bridge.tar.gz',
  checksumsUrl: 'https://example.com/checksums.txt',
  publishedAt: DateTime.utc(2026),
);

void main() {
  late _FakeReleaseRepository release;
  late _FakeInstallService install;
  late _FakeApplyService apply;
  late _FakeLogRepository logs;
  late List<String> infoMessages;
  late List<String> errors;
  late List<String> warnings;

  UpdateService buildService({
    String executablePath = _managedPath,
    Map<String, String> environment = const {},
    bool isSupervised = false,
  }) {
    final service = UpdateService(
      releaseRepository: release,
      updateInstallService: install,
      updateApplyService: apply,
      logRepository: logs,
      messageFormatter: const UpdateMessageFormatter(),
      installRoot: '/tmp/install',
      executablePath: executablePath,
      managedExecutablePath: _managedPath,
      environment: environment,
      isSupervised: isSupervised,
    );
    service.emitMessage = infoMessages.add;
    service.emitError = errors.add;
    service.logWarning = warnings.add;
    return service;
  }

  setUp(() {
    release = _FakeReleaseRepository();
    install = _FakeInstallService();
    apply = _FakeApplyService();
    logs = _FakeLogRepository();
    infoMessages = <String>[];
    errors = <String>[];
    warnings = <String>[];
  });

  void runStarted(UpdateService service, void Function(FakeAsync async) body) {
    fakeAsync((async) {
      service.start();
      async.flushMicrotasks();
      body(async);
      service.dispose();
      async.flushMicrotasks();
    });
  }

  test('newer release is staged and applied on the initial cycle', () {
    release.onCheck = () async => _release(version: '2.0.0');

    runStarted(buildService(), (async) {
      expect(release.checkCount, 1);
      expect(install.stageCount, 1);
      expect(apply.appliedVersions, equals(['2.0.0']));
      expect(infoMessages.single, contains('2.0.0'));
      expect(errors, isEmpty);
    });
  });

  test('a successful apply advances the release baseline and keeps polling', () {
    release.onCheck = () async => _release(version: '2.0.0');

    runStarted(buildService(), (async) {
      expect(apply.appliedVersions, equals(['2.0.0']));
      // The cycle advanced the comparison baseline instead of stopping.
      expect(release.advancedBaselines, equals(['2.0.0']));
    });
  });

  test('further releases published in-session are chained without a restart', () {
    // The fake repository stands in for the real baseline advance: after a
    // version is staged, only strictly-newer releases surface on later cycles.
    final available = <String>['2.0.0', '2.1.0'];
    release.onCheck = () async => available.isEmpty ? null : _release(version: available.first);
    final service = buildService();

    fakeAsync((async) {
      service.start();
      async.flushMicrotasks();

      // Cycle 1 applies 2.0.0 and advances the baseline.
      expect(apply.appliedVersions, equals(['2.0.0']));
      expect(release.advancedBaselines, equals(['2.0.0']));
      available.removeAt(0); // 2.0.0 is no longer "newer" than the baseline.

      // Cycle 2 fires after the poll interval and applies 2.1.0 — no restart.
      async.elapse(const Duration(hours: 4));
      async.flushMicrotasks();
      expect(apply.appliedVersions, equals(['2.0.0', '2.1.0']));
      expect(release.advancedBaselines, equals(['2.0.0', '2.1.0']));

      // With nothing newer left, later cycles do not re-apply anything.
      available.removeAt(0);
      async.elapse(const Duration(hours: 4));
      async.flushMicrotasks();
      expect(apply.appliedVersions, equals(['2.0.0', '2.1.0']));

      service.dispose();
      async.flushMicrotasks();
    });
  });

  test('when the applier cannot chain in-session, polling stops after one apply', () {
    // Windows keeps the displaced backup locked until a restart, so a second
    // in-session apply would collide with it. The updater must stop instead.
    apply.supportsInSessionChaining = false;
    var version = 2;
    release.onCheck = () async => _release(version: '$version.0.0');

    runStarted(buildService(), (async) {
      expect(apply.appliedVersions, equals(['2.0.0']));
      expect(release.advancedBaselines, isEmpty);

      // Even with a newer release available, no further cycle runs.
      version = 3;
      async.elapse(const Duration(hours: 8));
      async.flushMicrotasks();
      expect(apply.appliedVersions, equals(['2.0.0']));
    });
  });

  test('an apply failure surfaces an error and stays quiet on success output', () {
    release.onCheck = () async => _release(version: '2.0.0');
    apply.onApply = (_) => const UpdateApplyFailed(reason: 'disk full', logPath: '/tmp/.sesori-bridge-update.log');

    runStarted(buildService(), (async) {
      expect(apply.appliedVersions, equals(['2.0.0']));
      expect(errors, hasLength(1));
      expect(errors.single, contains('disk full'));
      expect(errors.single, contains('https://sesori.com/'));
      expect(infoMessages, isEmpty);
    });
  });

  test('apply lock contention stays quiet', () {
    release.onCheck = () async => _release(version: '2.0.0');
    apply.onApply = (_) => const UpdateApplyLockBusy();

    runStarted(buildService(), (async) {
      expect(apply.appliedVersions, equals(['2.0.0']));
      expect(errors, isEmpty);
      expect(infoMessages, isEmpty);
    });
  });

  test('no newer release does not stage or apply', () {
    runStarted(buildService(), (async) {
      expect(release.checkCount, 1);
      expect(install.stageCount, 0);
      expect(apply.appliedVersions, isEmpty);
    });
  });

  test('a genuine stage failure surfaces an error and does not apply', () {
    release.onCheck = () async => _release();
    install.result = const UpdateInstallResult.failed(result: UpdateResult.checksumFailed);

    runStarted(buildService(), (async) {
      expect(apply.appliedVersions, isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single, contains('https://sesori.com/'));
      expect(logs.messages, isNotEmpty);
    });
  });

  test('a transient stage failure stays quiet', () {
    release.onCheck = () async => _release();
    install.result = const UpdateInstallResult.failed(result: UpdateResult.networkError);

    runStarted(buildService(), (async) {
      expect(apply.appliedVersions, isEmpty);
      expect(errors, isEmpty);
      expect(warnings, hasLength(1));
    });
  });

  test('a rate limit is benign: a warning, not an error', () {
    release.onCheck = () async => throw GitHubRateLimitException(resetAt: DateTime(2030), authenticated: false);

    runStarted(buildService(), (async) {
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('rate limit'));
      expect(errors, isEmpty);
      expect(install.stageCount, 0);
    });
  });

  test('dispose during the release check prevents staging and applying', () {
    late UpdateService service;
    release.onCheck = () async {
      // Tear down the subsystem while the awaited release check is in flight.
      await service.dispose();
      return _release(version: '2.0.0'); // a newer release that would otherwise apply
    };
    service = buildService();

    fakeAsync((async) {
      service.start();
      async.flushMicrotasks();

      expect(release.checkCount, 1);
      // The disposed cycle bailed before any destructive work.
      expect(install.stageCount, 0);
      expect(apply.appliedVersions, isEmpty);
    });
  });

  group('gating', () {
    test('CI environment disables the pipeline', () {
      runStarted(buildService(environment: const {'CI': 'true'}), (async) {
        async.elapse(const Duration(hours: 8));
        async.flushMicrotasks();
        expect(release.checkCount, 0);
      });
    });

    test('npm install disables the pipeline', () {
      runStarted(buildService(executablePath: '/tmp/node_modules/.bin/sesori-bridge'), (async) {
        expect(release.checkCount, 0);
      });
    });

    test('SESORI_NO_UPDATE disables the pipeline', () {
      runStarted(buildService(environment: const {'SESORI_NO_UPDATE': '1'}), (async) {
        expect(release.checkCount, 0);
      });
    });

    test('an unmanaged executable path disables the pipeline', () {
      runStarted(buildService(executablePath: '/somewhere/else/sesori-bridge'), (async) {
        expect(release.checkCount, 0);
      });
    });

    test('supervised mode disables the pipeline even on the managed install', () {
      runStarted(buildService(isSupervised: true), (async) {
        async.elapse(const Duration(hours: 8));
        async.flushMicrotasks();
        expect(release.checkCount, 0);
      });
    });
  });
}
