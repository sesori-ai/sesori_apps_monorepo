import 'dart:io' show Platform;

import 'package:sesori_bridge/src/updater/foundation/update_policy.dart';
import 'package:sesori_bridge/src/updater/models/distribution_target.dart';
import 'package:sesori_bridge/src/updater/services/managed_runtime_path_service.dart';
import 'package:sesori_plugin_runtime/sesori_plugin_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('DistributionTarget', () {
    test('returns correct asset name for every supported target', () {
      final targets = <(DistributionTarget, String)>[
        (
          DistributionTarget(
            os: PlatformOs.macos,
            arch: PlatformArch.arm64,
          ),
          'sesori-bridge-macos-arm64.tar.gz',
        ),
        (
          DistributionTarget(
            os: PlatformOs.macos,
            arch: PlatformArch.x64,
          ),
          'sesori-bridge-macos-x64.tar.gz',
        ),
        (
          DistributionTarget(
            os: PlatformOs.linux,
            arch: PlatformArch.x64,
          ),
          'sesori-bridge-linux-x64.tar.gz',
        ),
        (
          DistributionTarget(
            os: PlatformOs.linux,
            arch: PlatformArch.arm64,
          ),
          'sesori-bridge-linux-arm64.tar.gz',
        ),
        (
          DistributionTarget(
            os: PlatformOs.windows,
            arch: PlatformArch.x64,
          ),
          'sesori-bridge-windows-x64.zip',
        ),
        (
          DistributionTarget(
            os: PlatformOs.windows,
            arch: PlatformArch.arm64,
          ),
          'sesori-bridge-windows-arm64.zip',
        ),
      ];

      for (final (target, expectedAssetName) in targets) {
        expect(target.assetName, equals(expectedAssetName));
      }
    });

    test('maps the archive format per platform', () {
      expect(
        DistributionTarget(os: PlatformOs.macos, arch: PlatformArch.arm64).archiveFormat,
        equals(ArchiveFormat.tarGz),
      );
      expect(
        DistributionTarget(os: PlatformOs.linux, arch: PlatformArch.x64).archiveFormat,
        equals(ArchiveFormat.tarGz),
      );
      expect(
        DistributionTarget(os: PlatformOs.windows, arch: PlatformArch.x64).archiveFormat,
        equals(ArchiveFormat.zip),
      );
    });
  });

  group('currentDistributionTarget', () {
    test('uses the canonical runtime target for current asset name', () {
      final target = currentDistributionTarget();

      expect(getCurrentAssetName(), equals(target.assetName));
    });
  });

  group('isNpmInstall', () {
    test('returns true when path contains node_modules', () {
      final result = isNpmInstall(
        executablePath: '/home/user/node_modules/@sesori/bridge/bin/bridge',
      );
      expect(result, isTrue);
    });

    test('returns true when node_modules is in the middle of path', () {
      final result = isNpmInstall(
        executablePath: '/path/node_modules/some/other/path/bridge',
      );
      expect(result, isTrue);
    });

    test('returns false when path does not contain node_modules', () {
      final result = isNpmInstall(
        executablePath: '/usr/local/bin/sesori-bridge',
      );
      expect(result, isFalse);
    });

    test('returns false for empty path', () {
      final result = isNpmInstall(executablePath: '');
      expect(result, isFalse);
    });

    test('returns false for home directory install', () {
      final result = isNpmInstall(
        executablePath: '/home/user/.local/share/sesori/bin/sesori-bridge',
      );
      expect(result, isFalse);
    });
  });

  group('isCiEnvironment', () {
    test('returns true when CI is set', () {
      final result = isCiEnvironment(environment: {'CI': 'true'});
      expect(result, isTrue);
    });

    test('returns true when GITHUB_ACTIONS is set', () {
      final result = isCiEnvironment(environment: {'GITHUB_ACTIONS': 'true'});
      expect(result, isTrue);
    });

    test('returns true when JENKINS_URL is set', () {
      final result = isCiEnvironment(environment: {'JENKINS_URL': 'http://jenkins'});
      expect(result, isTrue);
    });

    test('returns true when CIRCLECI is set', () {
      final result = isCiEnvironment(environment: {'CIRCLECI': 'true'});
      expect(result, isTrue);
    });

    test('returns true when GITLAB_CI is set', () {
      final result = isCiEnvironment(environment: {'GITLAB_CI': 'true'});
      expect(result, isTrue);
    });

    test('returns true when CODESPACES is set', () {
      final result = isCiEnvironment(environment: {'CODESPACES': 'true'});
      expect(result, isTrue);
    });

    test('returns true when TF_BUILD is set', () {
      final result = isCiEnvironment(environment: {'TF_BUILD': 'true'});
      expect(result, isTrue);
    });

    test('returns false when no CI variables are set', () {
      final result = isCiEnvironment(environment: {'PATH': '/usr/bin'});
      expect(result, isFalse);
    });

    test('returns false for empty environment', () {
      final result = isCiEnvironment(environment: {});
      expect(result, isFalse);
    });

    test('returns true when multiple CI variables are set', () {
      final result = isCiEnvironment(
        environment: {
          'CI': 'true',
          'GITHUB_ACTIONS': 'true',
          'PATH': '/usr/bin',
        },
      );
      expect(result, isTrue);
    });
  });

  group('isUpdateDisabled', () {
    test('returns true when SESORI_NO_UPDATE is set', () {
      final result = isUpdateDisabled(environment: {'SESORI_NO_UPDATE': '1'});
      expect(result, isTrue);
    });

    test('returns true when SESORI_NO_UPDATE is set to any value', () {
      final result = isUpdateDisabled(environment: {'SESORI_NO_UPDATE': 'true'});
      expect(result, isTrue);
    });

    test('returns false when SESORI_NO_UPDATE is not set', () {
      final result = isUpdateDisabled(environment: {'PATH': '/usr/bin'});
      expect(result, isFalse);
    });

    test('returns false for empty environment', () {
      final result = isUpdateDisabled(environment: {});
      expect(result, isFalse);
    });
  });

  group('getInstallRoot', () {
    test('returns ~/.local/share/sesori on Unix when HOME is set', () {
      final root = const ManagedRuntimePathService().currentPaths(environment: Platform.environment).installRoot;
      if (!Platform.isWindows) {
        expect(root, endsWith('/.local/share/sesori'));
      }
    });

    test('returns correct path format on Windows', () {
      // On Windows, the path should contain sesori\ at the end
      final root = const ManagedRuntimePathService().currentPaths(environment: Platform.environment).installRoot;
      if (Platform.isWindows) {
        expect(root, endsWith(r'\sesori'));
      }
    });
  });

  group('getBinaryPath', () {
    test('returns correct path format on Unix', () {
      final path = const ManagedRuntimePathService().currentPaths(environment: Platform.environment).binaryPath;
      if (!Platform.isWindows) {
        expect(path, endsWith('/bin/sesori-bridge'));
        expect(path, contains('/.local/share/sesori'));
      }
    });

    test('returns correct path format on Windows', () {
      final path = const ManagedRuntimePathService().currentPaths(environment: Platform.environment).binaryPath;
      if (Platform.isWindows) {
        expect(path, endsWith(r'\sesori-bridge.exe'));
        expect(path, contains(r'\sesori\'));
      }
    });
  });

  group('getCacheDirectory', () {
    test('returns correct path format on Unix', () {
      final dir = const ManagedRuntimePathService().currentPaths(environment: Platform.environment).cacheDirectory;
      if (!Platform.isWindows) {
        expect(dir, endsWith('/.local/share/sesori'));
      }
    });

    test('returns correct path format on Windows', () {
      final dir = const ManagedRuntimePathService().currentPaths(environment: Platform.environment).cacheDirectory;
      if (Platform.isWindows) {
        expect(dir, endsWith(r'\sesori'));
      }
    });
  });
}
