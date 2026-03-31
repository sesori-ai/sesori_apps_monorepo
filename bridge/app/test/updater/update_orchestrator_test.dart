import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/models/update_result.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
import 'package:sesori_bridge/src/updater/services/update_installer_service.dart';
import 'package:sesori_bridge/src/updater/services/update_service.dart';
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

class _MockUpdateInstallerService implements UpdateInstallerService {
  int performUpdateCallCount = 0;
  int reExecCallCount = 0;
  UpdateResult performUpdateResult = UpdateResult.success;
  Object? performUpdateError;
  ReleaseInfo? lastPerformUpdateRelease;
  String? lastInstallRoot;
  List<String>? lastReExecArgs;
  @override
  void Function(String message) writeToStderr = (_) {};

  @override
  Future<UpdateResult> performUpdate({
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

  @override
  Future<Never> reExec({required List<String> args}) async {
    reExecCallCount++;
    lastReExecArgs = List<String>.from(args);
    throw _ReExecTriggered();
  }
}

class _ReExecTriggered implements Exception {}

ReleaseInfo _release({String version = '9.9.9'}) {
  return ReleaseInfo(
    version: version,
    assetUrl: 'https://example.com/bridge.tar.gz',
    checksumsUrl: 'https://example.com/checksums.txt',
    publishedAt: DateTime(2024, 1, 1),
  );
}

UpdateService _buildService({
  required ReleaseRepository repository,
  required UpdateInstallerService updater,
  required String executablePath,
  required Map<String, String> environment,
}) {
  return UpdateService(
    releaseRepository: repository,
    updateInstallerService: updater,
    executablePath: executablePath,
    managedExecutablePath: '/usr/local/bin/sesori-bridge',
    environment: environment,
  );
}

void main() {
  group('UpdateService.checkAndApplyUpdate', () {
    test('newer version → checker, updater, and reExec are called', () async {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '1.2.3');
      final updater = _MockUpdateInstallerService()..performUpdateResult = UpdateResult.success;

      final service = _buildService(
        repository: repository,
        updater: updater,
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );
      service.hasTerminal = () => false;

      await service.checkAndApplyUpdate(cliArgs: ['--relay', 'wss://example.com']);

      expect(repository.checkCallCount, equals(1));
      expect(updater.performUpdateCallCount, equals(1));
      expect(updater.reExecCallCount, equals(1));
      expect(updater.lastReExecArgs, equals(['--relay', 'wss://example.com']));
    });

    test('no update available → updater is not called', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(1));
      expect(updater.performUpdateCallCount, equals(0));
      expect(updater.reExecCallCount, equals(0));
    });

    test('update failure throws internally → exception is caught, no reExec', () async {
      final repository = _MockReleaseRepository()..onCheckForNewerRelease = () async => _release(version: '1.2.3');
      final updater = _MockUpdateInstallerService()..performUpdateError = StateError('boom');

      final service = _buildService(
        repository: repository,
        updater: updater,
        executablePath: '/usr/local/bin/sesori-bridge',
        environment: const {},
      );

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(1));
      expect(updater.performUpdateCallCount, equals(1));
      expect(updater.reExecCallCount, equals(0));
    });

    test('CI guard enabled → repository is never called', () async {
      final repository = _MockReleaseRepository();
      final updater = _MockUpdateInstallerService();

      final service = _buildService(
        repository: repository,
        updater: updater,
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
