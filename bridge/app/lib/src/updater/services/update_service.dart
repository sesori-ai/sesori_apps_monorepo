import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sesori_shared/sesori_shared.dart';

import '../models/release_info.dart';
import '../models/update_result.dart';
import '../platform_info.dart';
import '../repositories/release_repository.dart';
import '../update_policy.dart';
import 'update_installer_service.dart';

class UpdateService {
  final ReleaseRepository _releaseRepository;
  final UpdateInstallerService _updateInstallerService;
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
    required UpdateInstallerService updateInstallerService,
    required String executablePath,
    required String managedExecutablePath,
    required Map<String, String> environment,
  }) : _releaseRepository = releaseRepository,
       _updateInstallerService = updateInstallerService,
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

      final installRoot = getInstallRoot();
      final result = await _updateInstallerService.performUpdate(
        release: release,
        installRoot: installRoot,
      );

      if (result == UpdateResult.success) {
        if (interactiveTerminal) {
          writeToStderr('Updated to ${release.version}. Restarting...');
        }
        await _updateInstallerService.reExec(args: cliArgs);
      }

      if (interactiveTerminal) {
        writeToStderr(
          'Warning: failed to update to ${release.version} ($result). Continuing with current version.',
        );
      }
    } on Object catch (error, stackTrace) {
      if (hasTerminal()) {
        writeToStderr('Warning: automatic update failed: $error\n$stackTrace');
      }
    }
  }
}
