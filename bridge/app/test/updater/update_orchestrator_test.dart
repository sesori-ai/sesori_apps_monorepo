import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/updater/foundation/github_rate_limit_exception.dart';
import 'package:sesori_bridge/src/updater/foundation/update_lock.dart';
import 'package:sesori_bridge/src/updater/foundation/update_relaunch_client.dart';
import 'package:sesori_bridge/src/updater/models/file_replacement_result.dart';
import 'package:sesori_bridge/src/updater/models/managed_runtime_paths.dart';
import 'package:sesori_bridge/src/updater/models/pending_windows_update.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/models/update_install_result.dart';
import 'package:sesori_bridge/src/updater/models/update_result.dart';
import 'package:sesori_bridge/src/updater/repositories/installed_file_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
import 'package:sesori_bridge/src/updater/services/update_install_service.dart';
import 'package:sesori_bridge/src/updater/services/update_service.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';

import 'package:test/test.dart';

class _MockReleaseRepository implements ReleaseRepository {
  int checkCallCount = 0;
  Future<ReleaseInfo?> Function()? onCheckForNewerRelease;

  @override
  Future<ReleaseInfo?> checkForNewerRelease() async {
    checkCallCount++;
    return onCheckForNewerRelease?.call();
  }
}

class _MockUpdateInstallerService implements UpdateInstallService {
  int performUpdateCallCount = 0;
  UpdateInstallResult performUpdateResult = const UpdateInstallResult.completed(
    result: UpdateResult.success,
  );
  Object? performUpdateError;
  ReleaseInfo? lastPerformUpdateRelease;
  String? lastInstallRoot;
  @override
  void Function(String message) writeToStderr = (_) {};

  @override
  Future<UpdateInstallResult> performUpdate({
    required ReleaseInfo release,
    required String installRoot,
  }) async {
    performUpdateCallCount++;
    lastPerformUpdateRelease = release;
    lastInstallRoot = installRoot;

    if (performUpdateError != null) {
      throw performUpdateError!;
    }
    return performUpdateResult;
  }
}

class _MockInstalledFileRepository implements InstalledFileRepository {
  @override
  Future<String> createWindowsSwapScript({
    required PendingWindowsUpdate pendingWindowsUpdate,
    required List<String> args,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<FileReplacementResult> replaceInstalledFiles({
    required String installRoot,
    required String stagingPath,
  }) async {
    throw UnimplementedError();
  }
}

class _MockUpdateRelaunchClient implements UpdateRelaunchClient {
  int relaunchBinaryCallCount = 0;
  String? lastBinaryPath;
  List<String>? lastBinaryArgs;

  @override
  Future<Never> relaunchBinary({
    required String binaryPath,
    required List<String> args,
  }) async {
    relaunchBinaryCallCount++;
    lastBinaryPath = binaryPath;
    lastBinaryArgs = List<String>.from(args);
    throw _RelaunchTriggered();
  }

  @override
  Future<Never> relaunchWindowsSwapScript({required String scriptPath}) async {
    throw UnimplementedError();
  }
}

class _RelaunchTriggered implements Exception {}

class _FakeProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return ProcessResult(1, 1, '', '');
  }
}

ReleaseInfo _release({String version = '9.9.9'}) {
  return ReleaseInfo(
    version: version,
    assetUrl: 'https://example.com/bridge.tar.gz',
    checksumsUrl: 'https://example.com/checksums.txt',
    publishedAt: DateTime(2024, 1, 1),
  );
}

const ManagedRuntimePaths _testManagedPaths = ManagedRuntimePaths(
  installRoot: '/tmp/sesori-managed-runtime-tests',
  binaryPath: '/usr/local/bin/sesori-bridge',
  cacheDirectory: '/tmp/sesori-bridge-cache',
);

UpdateService _buildService({
  required ReleaseRepository repository,
  required UpdateInstallService updater,
  required InstalledFileRepository installedFileRepository,
  required UpdateRelaunchClient updateRelaunchClient,
  required String executablePath,
  required Map<String, String> environment,
}) {
  return UpdateService(
    releaseRepository: repository,
    updateInstallerService: updater,
    installedFileRepository: installedFileRepository,
    updateLock: UpdateLock(currentPid: 999999, processRunner: _FakeProcessRunner()),
    updateRelaunchClient: updateRelaunchClient,
    installRoot: _testManagedPaths.installRoot,
    executablePath: executablePath,
    managedExecutablePath: _testManagedPaths.binaryPath,
    environment: environment,
  );
}

void main() {
  setUp(() async {
    await Directory(_testManagedPaths.installRoot).create(recursive: true);
    final lockFile = File('${_testManagedPaths.installRoot}/.update.lock');
    if (lockFile.existsSync()) {
      await lockFile.delete();
    }
  });

  tearDown(() async {
    final lockFile = File('${_testManagedPaths.installRoot}/.update.lock');
    if (lockFile.existsSync()) {
      await lockFile.delete();
    }
  });

  group('UpdateService.checkAndApplyUpdate', () {
    test('newer version → checker, updater, and relaunch are called', () async {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '1.2.3');
      final updater = _MockUpdateInstallerService();
      final relaunchClient = _MockUpdateRelaunchClient();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: relaunchClient,
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );
      service.hasTerminal = () => false;

      await service.checkAndApplyUpdate(cliArgs: ['--relay', 'wss://example.com']);

      expect(repository.checkCallCount, equals(1));
      expect(updater.performUpdateCallCount, equals(1));
      expect(relaunchClient.relaunchBinaryCallCount, equals(1));
      expect(relaunchClient.lastBinaryArgs, equals(['--relay', 'wss://example.com']));
    });

    test('no update available → updater is not called', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(1));
      expect(updater.performUpdateCallCount, equals(0));
    });

    test('update failure throws internally → exception is caught, no relaunch', () async {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '1.2.3');
      final updater = _MockUpdateInstallerService()..performUpdateError = StateError('boom');

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(1));
      expect(updater.performUpdateCallCount, equals(1));
    });

    test('rate-limited check → friendly warning on stdout, no stack trace', () async {
      final repository = _MockReleaseRepository()
        ..onCheckForNewerRelease = () async =>
            throw GitHubRateLimitException(resetAt: DateTime(2030, 1, 1, 9, 5));
      final service = _buildService(
        repository: repository,
        updater: _MockUpdateInstallerService(),
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      await IOOverrides.runZoned(
        () => service.checkAndApplyUpdate(cliArgs: const []),
        stdout: () => _CapturingStdout(stdoutLines),
        stderr: () => _CapturingStdout(stderrLines),
      );

      // A rate limit is benign, so it is logged via Log.w (stdout), not the
      // alarming Log.e (stderr) path.
      expect(stdoutLines, hasLength(1));
      final message = stdoutLines.single;
      expect(message, contains('rate limit'));
      expect(message, contains('GITHUB_TOKEN'));
      expect(message, contains('09:05'));
      expect(message, isNot(contains('#0')));
      expect(stderrLines, isEmpty);
    });

    test('unexpected failure → error on stderr, stack trace suppressed at info level', () async {
      final repository = _MockReleaseRepository()
        ..onCheckForNewerRelease = () async => throw StateError('network exploded');
      final service = _buildService(
        repository: repository,
        updater: _MockUpdateInstallerService(),
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      final stderrLines = <String>[];
      await IOOverrides.runZoned(
        () => service.checkAndApplyUpdate(cliArgs: const []),
        stdout: () => _CapturingStdout(<String>[]),
        stderr: () => _CapturingStdout(stderrLines),
      );

      // Log.e writes to stderr; at the default info level the raw error and
      // async stack trace are not appended, so the line stays clean.
      expect(stderrLines, hasLength(1));
      expect(stderrLines.single, contains('Automatic update failed'));
      expect(stderrLines.single, isNot(contains('#0')));
    });

    test('unexpected failure preserves error + stack trace at debug level', () async {
      final previousLevel = Log.level;
      Log.level = LogLevel.debug;
      addTearDown(() => Log.level = previousLevel);

      final repository = _MockReleaseRepository()
        ..onCheckForNewerRelease = () async => throw StateError('network exploded');
      final service = _buildService(
        repository: repository,
        updater: _MockUpdateInstallerService(),
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      final stderrLines = <String>[];
      await IOOverrides.runZoned(
        () => service.checkAndApplyUpdate(cliArgs: const []),
        stdout: () => _CapturingStdout(<String>[]),
        stderr: () => _CapturingStdout(stderrLines),
      );

      expect(stderrLines, isNotEmpty);
      expect(stderrLines.join('\n'), contains('network exploded'));
    });

    test('CI guard enabled → repository is never called', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {'CI': 'true'},
      );

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(0));
      expect(updater.performUpdateCallCount, equals(0));
    });

    test('npm install guard enabled → repository is never called', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/tmp/node_modules/.bin/sesori-bridge',
        environment: const {},
      );

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(0));
      expect(updater.performUpdateCallCount, equals(0));
    });

    test('SESORI_NO_UPDATE guard enabled → repository is never called', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {'SESORI_NO_UPDATE': '1'},
      );

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(0));
      expect(updater.performUpdateCallCount, equals(0));
    });

    test('non-TTY does not skip startup update check', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );
      service.hasTerminal = () => false;

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(1));
      expect(updater.performUpdateCallCount, equals(0));
    });

    test('managed install gating requires exact executable path, not install root prefix', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin',
        environment: const {},
      );

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(0));
      expect(updater.performUpdateCallCount, equals(0));
    });

    test('managed install gating accepts normalized executable path equality', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/../bin/sesori-bridge',
        environment: const {},
      );
      service.hasTerminal = () => false;

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(1));
      expect(updater.performUpdateCallCount, equals(0));
    });
  });

  group('UpdateService.updateAvailable', () {
    test('does not check until subscribed, then emits immediate result', () {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '2.0.0');
      final updater = _MockUpdateInstallerService();
      final versions = <String>[];

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      fakeAsync((async) {
        async.elapse(const Duration(hours: 8));
        async.flushMicrotasks();
        expect(repository.checkCallCount, equals(0));

        final subscription = service.updateAvailable.listen(versions.add);
        async.flushMicrotasks();

        expect(repository.checkCallCount, equals(1));
        expect(versions, equals(['2.0.0']));

        subscription.cancel();
        async.flushMicrotasks();
      });
    });

    test('same version only emits once per active subscription lifecycle', () {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '2.1.0');
      final updater = _MockUpdateInstallerService();
      final versions = <String>[];

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      fakeAsync((async) {
        final subscription = service.updateAvailable.listen(versions.add);
        async.flushMicrotasks();
        async.elapse(const Duration(hours: 4));
        async.flushMicrotasks();

        expect(repository.checkCallCount, equals(2));
        expect(versions, equals(['2.1.0']));

        subscription.cancel();
        async.flushMicrotasks();
      });
    });

    test('canceling all listeners resets state for a later subscriber', () {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '3.0.0');
      final updater = _MockUpdateInstallerService();
      final firstRunVersions = <String>[];
      final secondRunVersions = <String>[];

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      fakeAsync((async) {
        final firstSubscription = service.updateAvailable.listen(firstRunVersions.add);
        async.flushMicrotasks();
        expect(firstRunVersions, equals(['3.0.0']));

        firstSubscription.cancel();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        async.elapse(const Duration(hours: 8));
        async.flushMicrotasks();

        expect(repository.checkCallCount, equals(1));

        final secondSubscription = service.updateAvailable.listen(secondRunVersions.add);
        async.flushMicrotasks();

        expect(repository.checkCallCount, equals(2));
        expect(secondRunVersions, equals(['3.0.0']));

        secondSubscription.cancel();
        async.flushMicrotasks();
      });
    });

    test('CI guard disables polling checks', () {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '4.0.0');
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {'CI': 'true'},
      );

      fakeAsync((async) {
        final subscription = service.updateAvailable.listen((_) {});
        async.flushMicrotasks();
        async.elapse(const Duration(hours: 8));
        async.flushMicrotasks();

        expect(repository.checkCallCount, equals(0));

        subscription.cancel();
        async.flushMicrotasks();
      });
    });

    test('npm install guard disables polling checks', () {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '4.1.0');
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/tmp/node_modules/.bin/sesori-bridge',
        environment: const {},
      );

      fakeAsync((async) {
        final subscription = service.updateAvailable.listen((_) {});
        async.flushMicrotasks();
        async.elapse(const Duration(hours: 8));
        async.flushMicrotasks();

        expect(repository.checkCallCount, equals(0));

        subscription.cancel();
        async.flushMicrotasks();
      });
    });

    test('SESORI_NO_UPDATE guard disables polling checks', () {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '4.2.0');
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {'SESORI_NO_UPDATE': '1'},
      );

      fakeAsync((async) {
        final subscription = service.updateAvailable.listen((_) {});
        async.flushMicrotasks();
        async.elapse(const Duration(hours: 8));
        async.flushMicrotasks();

        expect(repository.checkCallCount, equals(0));

        subscription.cancel();
        async.flushMicrotasks();
      });
    });

    test('polling failures stay internal and later cycles continue', () {
      final repository = _MockReleaseRepository();
      repository.onCheckForNewerRelease = () async {
        if (repository.checkCallCount == 1) {
          throw StateError('boom');
        }

        return _release(version: '4.3.0');
      };
      final updater = _MockUpdateInstallerService();
      final versions = <String>[];
      final zoneErrors = <Object>[];

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      runZonedGuarded(
        () {
          fakeAsync((async) {
            final subscription = service.updateAvailable.listen(versions.add);
            async.flushMicrotasks();

            expect(versions, isEmpty);
            expect(zoneErrors, isEmpty);

            async.elapse(const Duration(hours: 4));
            async.flushMicrotasks();

            expect(repository.checkCallCount, equals(2));
            expect(versions, equals(['4.3.0']));
            expect(zoneErrors, isEmpty);

            subscription.cancel();
            async.flushMicrotasks();
          });
        },
        (error, stackTrace) {
          zoneErrors.add(error);
        },
      );
    });

    test('success, failure, then newer success still emits only new versions', () {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();
      final versions = <String>[];

      final service = _buildService(
        repository: repository,
        updater: updater,
        installedFileRepository: _MockInstalledFileRepository(),
        updateRelaunchClient: _MockUpdateRelaunchClient(),
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      repository.onCheckForNewerRelease = () async {
        switch (repository.checkCallCount) {
          case 1:
            return _release(version: '4.4.0');
          case 2:
            throw StateError('transient poll failure');
          case 3:
            return _release(version: '4.4.0');
          case 4:
            return _release(version: '4.5.0');
          default:
            return null;
        }
      };

      final zoneErrors = <Object>[];

      runZonedGuarded(
        () {
          fakeAsync((async) {
            final subscription = service.updateAvailable.listen(versions.add);
            async.flushMicrotasks();

            expect(versions, equals(['4.4.0']));

            async.elapse(const Duration(hours: 4));
            async.flushMicrotasks();
            expect(versions, equals(['4.4.0']));

            async.elapse(const Duration(hours: 4));
            async.flushMicrotasks();
            expect(versions, equals(['4.4.0']));

            async.elapse(const Duration(hours: 4));
            async.flushMicrotasks();

            expect(repository.checkCallCount, equals(4));
            expect(versions, equals(['4.4.0', '4.5.0']));
            expect(zoneErrors, isEmpty);

            subscription.cancel();
            async.flushMicrotasks();
          });
        },
        (error, stackTrace) {
          zoneErrors.add(error);
        },
      );
    });
  });
}

/// Captures `writeln` calls; [IOOverrides] swaps it in for stdout/stderr so
/// tests can assert on what `Log` emitted.
class _CapturingStdout implements Stdout {
  _CapturingStdout(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = '']) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
