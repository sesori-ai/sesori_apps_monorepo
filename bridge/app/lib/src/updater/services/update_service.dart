import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';
import 'package:sesori_shared/sesori_shared.dart';

import '../foundation/update_lock.dart';
import '../foundation/update_policy.dart';
import '../foundation/update_relaunch_client.dart';
import '../models/release_info.dart';
import '../models/update_install_result.dart';
import '../models/update_result.dart';
import '../repositories/installed_file_repository.dart';
import '../repositories/release_repository.dart';
import 'update_install_service.dart';

class UpdateService {
  final ReleaseRepository _releaseRepository;
  final UpdateInstallService _updateInstallerService;
  final InstalledFileRepository _installedFileRepository;
  final UpdateLock _updateLock;
  final UpdateRelaunchClient _updateRelaunchClient;
  final String _installRoot;
  final String _executablePath;
  final String _managedExecutablePath;
  final Map<String, String> _environment;

  String? _lastNotifiedVersion;

  late final Stream<String> updateAvailable = RefCountReusableStream<String>.publish(
    () =>
        (_isUpdatePollingDisabled()
                ? const Stream<ReleaseInfo?>.empty()
                : Rx.concat<Null>([
                    Stream<Null>.value(null),
                    Stream<Null>.periodic(
                      const Duration(hours: 4),
                      (_) => null,
                    ),
                  ]).asyncMap((_) => _checkForPollingUpdate()))
            .whereNotNull()
            .map((release) => release.version)
            .where((version) {
              if (_lastNotifiedVersion == version) {
                return false;
              }
              _lastNotifiedVersion = version;
              return true;
            })
            .distinct(),
    onCancel: () {
      _lastNotifiedVersion = null;
    },
  );

  @visibleForTesting
  bool Function() hasTerminal = () => stdout.hasTerminal;

  @visibleForTesting
  void Function(String message) writeToStderr = stderr.writeln;

  UpdateService({
    required ReleaseRepository releaseRepository,
    required UpdateInstallService updateInstallerService,
    required InstalledFileRepository installedFileRepository,
    required UpdateLock updateLock,
    required UpdateRelaunchClient updateRelaunchClient,
    required String installRoot,
    required String executablePath,
    required String managedExecutablePath,
    required Map<String, String> environment,
  }) : _releaseRepository = releaseRepository,
       _updateInstallerService = updateInstallerService,
       _installedFileRepository = installedFileRepository,
       _updateLock = updateLock,
       _updateRelaunchClient = updateRelaunchClient,
       _installRoot = installRoot,
       _executablePath = executablePath,
       _managedExecutablePath = managedExecutablePath,
       _environment = environment;

  bool _isUpdatePollingDisabled() {
    return isUpdateDisabled(environment: _environment) ||
        isCiEnvironment(environment: _environment) ||
        isNpmInstall(executablePath: _executablePath);
  }

  bool _shouldSkipStartupUpdateCheck() {
    return _isUpdatePollingDisabled() ||
        !isManagedInstall(
          executablePath: _executablePath,
          managedExecutablePath: _managedExecutablePath,
        );
  }

  Future<ReleaseInfo?> _checkForPollingUpdate() async {
    try {
      return await _releaseRepository.checkForNewerRelease();
    } on Object catch (error, stackTrace) {
      writeToStderr('Warning: periodic update check failed: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> checkAndApplyUpdate({required List<String> cliArgs}) async {
    try {
      if (_shouldSkipStartupUpdateCheck()) {
        return;
      }

      final release = await _releaseRepository.checkForNewerRelease();
      if (release == null) {
        return;
      }

      final bool interactiveTerminal = hasTerminal();
      if (interactiveTerminal) {
        writeToStderr('Updating to ${release.version}...');
      }

      final UpdateInstallResult installResult = await _updateLock.locked<UpdateInstallResult>(
        lockFile: File(p.join(_installRoot, '.update.lock')),
        onLockAcquired: () {
          return _updateInstallerService.performUpdate(
            release: release,
            installRoot: _installRoot,
          );
        },
        onLockRejected: (lockResult) async {
          return switch (lockResult) {
            LockAcquireResult.alreadyLocked => const UpdateInstallResult.completed(
              result: UpdateResult.alreadyLocked,
            ),
            LockAcquireResult.permissionDenied => const UpdateInstallResult.completed(
              result: UpdateResult.permissionDenied,
            ),
            LockAcquireResult.acquired => throw StateError(
              'Unexpected acquired state in onLockRejected',
            ),
          };
        },
        shouldReleaseLock: (installResult) {
          return installResult.pendingWindowsUpdate == null;
        },
      );

      if (installResult.result == UpdateResult.success) {
        if (interactiveTerminal) {
          writeToStderr('Updated to ${release.version}. Restarting...');
        }
        await _restartUpdatedBridge(
          cliArgs: cliArgs,
          installResult: installResult,
        );
      }

      if (interactiveTerminal) {
        writeToStderr(
          'Warning: failed to update to ${release.version} (${installResult.result}). Continuing with current version.',
        );
      }
    } on Object catch (error, stackTrace) {
      if (hasTerminal()) {
        writeToStderr('Warning: automatic update failed: $error\n$stackTrace');
      }
    }
  }

  Future<Never> _restartUpdatedBridge({
    required List<String> cliArgs,
    required UpdateInstallResult installResult,
  }) async {
    final pendingWindowsUpdate = installResult.pendingWindowsUpdate;
    if (Platform.isWindows && pendingWindowsUpdate != null) {
      final String scriptPath = await _installedFileRepository.createWindowsSwapScript(
        pendingWindowsUpdate: pendingWindowsUpdate,
        args: cliArgs,
      );
      await _updateRelaunchClient.relaunchWindowsSwapScript(scriptPath: scriptPath);
    }

    await _updateRelaunchClient.relaunchBinary(
      binaryPath: _managedExecutablePath,
      args: cliArgs,
    );
  }
}
