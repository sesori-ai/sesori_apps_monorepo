import 'dart:io' show Platform;

import 'package:sesori_bridge/src/updater/platform_info.dart';
import 'package:sesori_bridge/src/updater/update_policy.dart';
import 'package:test/test.dart';

void main() {
  group('DistributionTarget', () {
    test('returns correct asset name for every supported target', () {
      final targets = <(DistributionTarget, String)>[
        (
          DistributionTarget(
            os: DistributionPlatformOs.macos,
            arch: DistributionPlatformArch.arm64,
          ),
          'sesori-bridge-macos-arm64.tar.gz',
        ),
        (
          DistributionTarget(
            os: DistributionPlatformOs.macos,
            arch: DistributionPlatformArch.x64,
          ),
          'sesori-bridge-macos-x64.tar.gz',
        ),
        (
          DistributionTarget(
            os: DistributionPlatformOs.linux,
            arch: DistributionPlatformArch.x64,
          ),
          'sesori-bridge-linux-x64.tar.gz',
        ),
        (
          DistributionTarget(
            os: DistributionPlatformOs.linux,
            arch: DistributionPlatformArch.arm64,
          ),
          'sesori-bridge-linux-arm64.tar.gz',
        ),
        (
          DistributionTarget(
            os: DistributionPlatformOs.windows,
            arch: DistributionPlatformArch.x64,
          ),
          'sesori-bridge-windows-x64.zip',
        ),
      ];

      for (final (target, expectedAssetName) in targets) {
        expect(target.assetName, equals(expectedAssetName));
      }
    });

    test('throws ArgumentError for unsupported combination', () {
      expect(
        () => DistributionTarget(
          os: DistributionPlatformOs.windows,
          arch: DistributionPlatformArch.arm64,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DistributionPlatformOs', () {
    test('maps supported runtime operating systems', () {
      expect(
        DistributionPlatformOs.fromPlatform(operatingSystem: 'macos'),
        equals(DistributionPlatformOs.macos),
      );
      expect(
        DistributionPlatformOs.fromPlatform(operatingSystem: 'linux'),
        equals(DistributionPlatformOs.linux),
      );
      expect(
        DistributionPlatformOs.fromPlatform(operatingSystem: 'windows'),
        equals(DistributionPlatformOs.windows),
      );
    });

    test('throws ArgumentError for unsupported os', () {
      expect(
        () => DistributionPlatformOs.fromPlatform(operatingSystem: 'freebsd'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DistributionPlatformArch', () {
    test('detects arm64 from runtime version variants', () {
      expect(
        DistributionPlatformArch.detectCurrent(platformVersion: 'Dart VM version on arm64'),
        equals(DistributionPlatformArch.arm64),
      );
      expect(
        DistributionPlatformArch.detectCurrent(platformVersion: 'Dart VM version on aarch64'),
        equals(DistributionPlatformArch.arm64),
      );
    });

    test('detects x64 from runtime version variants', () {
      expect(
        DistributionPlatformArch.detectCurrent(platformVersion: 'Dart VM version on x86_64'),
        equals(DistributionPlatformArch.x64),
      );
      expect(
        DistributionPlatformArch.detectCurrent(platformVersion: 'Dart VM version on x64'),
        equals(DistributionPlatformArch.x64),
      );
    });

    test('throws ArgumentError when runtime version is unknown', () {
      expect(
        () => DistributionPlatformArch.detectCurrent(
          platformVersion: 'Dart VM version on something-else',
        ),
        throwsA(isA<ArgumentError>()),
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
        executablePath: '/home/user/.sesori/bin/sesori-bridge',
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
    test('returns ~/.sesori on Unix when HOME is set', () {
      // This test uses the actual Platform.environment, so we can only verify
      // the format is correct. On Unix systems, it should end with /.sesori/
      final root = getInstallRoot();
      if (!Platform.isWindows) {
        expect(root, endsWith('/.sesori'));
      }
    });

    test('returns correct path format on Windows', () {
      // On Windows, the path should contain sesori\ at the end
      final root = getInstallRoot();
      if (Platform.isWindows) {
        expect(root, endsWith(r'\sesori'));
      }
    });
  });

  group('getBinaryPath', () {
    test('returns correct path format on Unix', () {
      final path = getBinaryPath();
      if (!Platform.isWindows) {
        expect(path, endsWith('/bin/sesori-bridge'));
        expect(path, contains('/.sesori'));
      }
    });

    test('returns correct path format on Windows', () {
      final path = getBinaryPath();
      if (Platform.isWindows) {
        expect(path, endsWith(r'\sesori-bridge.exe'));
        expect(path, contains(r'\sesori\'));
      }
    });
  });

  group('getCacheDirectory', () {
    test('returns correct path format on Unix', () {
      final dir = getCacheDirectory();
      if (!Platform.isWindows) {
        expect(dir, endsWith('/.config/sesori-bridge'));
      }
    });

    test('returns correct path format on Windows', () {
      final dir = getCacheDirectory();
      if (Platform.isWindows) {
        expect(dir, endsWith(r'\sesori\cache'));
      }
    });
  });
}
