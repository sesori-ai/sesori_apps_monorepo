import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/updater/api/archive_extractor_api.dart';
import 'package:sesori_bridge/src/updater/api/checksum_manifest_api.dart';
import 'package:sesori_bridge/src/updater/api/checksum_verifier_api.dart';
import 'package:sesori_bridge/src/updater/api/file_replacement_api.dart';
import 'package:sesori_bridge/src/updater/api/update_download_api.dart';
import 'package:sesori_bridge/src/updater/models/checksum_manifest.dart';
import 'package:sesori_bridge/src/updater/models/pending_windows_update.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/models/update_result.dart';
import 'package:sesori_bridge/src/updater/repositories/installed_file_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
import 'package:sesori_bridge/src/updater/repositories/update_artifact_repository.dart';
import 'package:sesori_bridge/src/updater/services/update_installer_service.dart';
import 'package:sesori_bridge/src/updater/services/update_service.dart';
import 'package:sesori_bridge/src/updater/update_lock.dart';
import 'package:test/test.dart';

class FakeUpdateHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;

  FakeUpdateHttpClient({required Future<http.StreamedResponse> Function(http.BaseRequest request) handler})
    : _handler = handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

class FakeChecksumVerifierApi extends ChecksumVerifierApi {
  final bool shouldPass;
  final Object? error;

  FakeChecksumVerifierApi({required this.shouldPass, this.error});

  @override
  Future<bool> verify({required String filePath, required String expectedHash}) async {
    if (error != null) {
      throw error!;
    }
    return shouldPass;
  }
}

class FakeChecksumManifestApi implements ChecksumManifestApi {
  final Map<String, String> entries;
  String? lastChecksumsUrl;

  FakeChecksumManifestApi({required this.entries});

  factory FakeChecksumManifestApi.single({
    required String fileName,
    required String checksum,
  }) {
    return FakeChecksumManifestApi(entries: {fileName: checksum});
  }

  @override
  Future<ChecksumManifest?> fetchManifest({required String url}) async {
    lastChecksumsUrl = url;
    return ChecksumManifest(entries: entries);
  }
}

class FakeProcessRunner implements ProcessRunner {
  final int exitCode;

  FakeProcessRunner({required this.exitCode});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return ProcessResult(1, exitCode, '', exitCode == 0 ? '' : 'chmod failed');
  }
}

class _FakeReleaseRepository implements ReleaseRepository {
  int checkCallCount = 0;
  Future<ReleaseInfo?> Function()? onCheckForNewerRelease;

  @override
  Future<ReleaseInfo?> checkForNewerRelease() async {
    checkCallCount++;
    return onCheckForNewerRelease?.call();
  }
}

class _FakeUpdateInstallerService implements UpdateInstallerService {
  int performUpdateCallCount = 0;
  int reExecCallCount = 0;
  UpdateResult performUpdateResult = UpdateResult.success;
  @override
  void Function(String message) writeToStderr = (_) {};

  @override
  Future<UpdateResult> performUpdate({
    required ReleaseInfo release,
    required String installRoot,
  }) async {
    performUpdateCallCount++;
    return performUpdateResult;
  }

  @override
  Future<Never> reExec({required List<String> args}) async {
    reExecCallCount++;
    throw StateError('reexec');
  }
}

void main() {
  late Directory rootTempDir;

  setUp(() async {
    rootTempDir = await Directory.systemTemp.createTemp('self_updater_test_');
  });

  tearDown(() async {
    await Process.run('chmod', ['-R', 'u+w', rootTempDir.path]);
    if (rootTempDir.existsSync()) {
      await rootTempDir.delete(recursive: true);
    }
  });

  group('UpdateInstallerService', () {
    test('successful update replaces binary and returns success', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      final String archivePath = await _createTarGzArchive(
        rootTempDir: rootTempDir,
        binaryContent: 'new-binary',
        includeLib: true,
      );
      final List<int> archiveBytes = await File(archivePath).readAsBytes();

      final FakeUpdateHttpClient httpClient = FakeUpdateHttpClient(
        handler: (http.BaseRequest request) async {
          expect(request.url.toString(), equals('https://example.com/bridge.tar.gz'));
          return http.StreamedResponse(
            Stream<List<int>>.value(archiveBytes),
            200,
          );
        },
      );

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(httpClient: httpClient),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.success));
      expect(
        await File('$installRoot/bin/sesori-bridge').readAsString(),
        equals('new-binary'),
      );
      expect(
        await File('$installRoot/lib/libsqlite3.dylib').readAsString(),
        equals('new-lib'),
      );
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('checksum lookup uses published release asset filename', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      final String archivePath = await _createTarGzArchive(
        rootTempDir: rootTempDir,
        binaryContent: 'new-binary',
        includeLib: false,
      );
      final List<int> archiveBytes = await File(archivePath).readAsBytes();
      final fakeChecksumManifestApi = FakeChecksumManifestApi.single(
        fileName: 'sesori-bridge-macos-arm64.tar.gz',
        checksum: 'expected',
      );

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (request) async {
              return http.StreamedResponse(Stream<List<int>>.value(archiveBytes), 200);
            },
          ),
        ),
        checksumManifestApi: fakeChecksumManifestApi,
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/download/sesori-bridge-macos-arm64.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.success));
      expect(
        fakeChecksumManifestApi.lastChecksumsUrl,
        equals('https://example.com/checksums.txt'),
      );
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('checksum mismatch keeps binary unchanged and returns checksumFailed', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      final String archivePath = await _createTarGzArchive(
        rootTempDir: rootTempDir,
        binaryContent: 'new-binary',
        includeLib: false,
      );
      final List<int> archiveBytes = await File(archivePath).readAsBytes();

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) async {
              return http.StreamedResponse(
                Stream<List<int>>.value(archiveBytes),
                200,
              );
            },
          ),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: false),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.checksumFailed));
      expect(
        await File('$installRoot/bin/sesori-bridge').readAsString(),
        equals('old-binary'),
      );
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('download failure returns downloadFailed and keeps files unchanged', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) async {
              return http.StreamedResponse(
                const Stream<List<int>>.empty(),
                500,
              );
            },
          ),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.downloadFailed));
      expect(
        await File('$installRoot/bin/sesori-bridge').readAsString(),
        equals('old-binary'),
      );
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('lock contention returns alreadyLocked when lock owner is alive', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      await File('$installRoot/.update.lock').writeAsString('$pid');

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) async {
              return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
            },
          ),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.alreadyLocked));
      expect(File('$installRoot/.update.lock').existsSync(), isTrue);
    });

    test('stale lockfile is removed and update proceeds', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      await File('$installRoot/.update.lock').writeAsString('999999999');

      final String archivePath = await _createTarGzArchive(
        rootTempDir: rootTempDir,
        binaryContent: 'fresh-binary',
        includeLib: false,
      );
      final List<int> archiveBytes = await File(archivePath).readAsBytes();

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) async {
              return http.StreamedResponse(
                Stream<List<int>>.value(archiveBytes),
                200,
              );
            },
          ),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.success));
      expect(await File('$installRoot/bin/sesori-bridge').readAsString(), equals('fresh-binary'));
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('cleanup on extraction failure leaves no temp files', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      final List<int> invalidArchive = 'not-an-archive'.codeUnits;

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) async {
              return http.StreamedResponse(
                Stream<List<int>>.value(invalidArchive),
                200,
              );
            },
          ),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.downloadFailed));
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('permission denied returns permissionDenied', () async {
      if (Platform.isWindows) {
        return;
      }

      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      await Process.run('chmod', ['0555', installRoot]);

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) async {
              return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
            },
          ),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.permissionDenied));

      await Process.run('chmod', ['0755', installRoot]);
    });

    test('unix chmod failure leaves install unchanged and returns permissionDenied', () async {
      if (Platform.isWindows) {
        return;
      }

      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );
      await Directory('$installRoot/lib').create(recursive: true);
      await File('$installRoot/lib/libsqlite3.dylib').writeAsString('old-lib');

      final String archivePath = await _createTarGzArchive(
        rootTempDir: rootTempDir,
        binaryContent: 'new-binary',
        includeLib: true,
      );
      final List<int> archiveBytes = await File(archivePath).readAsBytes();

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) async {
              return http.StreamedResponse(Stream<List<int>>.value(archiveBytes), 200);
            },
          ),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
        fileReplacementApi: FileReplacementApi(processRunner: FakeProcessRunner(exitCode: 1)),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.permissionDenied));
      expect(await File('$installRoot/bin/sesori-bridge').readAsString(), equals('old-binary'));
      expect(await File('$installRoot/lib/libsqlite3.dylib').readAsString(), equals('old-lib'));
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('checksum verifier exception degrades to checksumFailed', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      final String archivePath = await _createTarGzArchive(
        rootTempDir: rootTempDir,
        binaryContent: 'new-binary',
        includeLib: false,
      );
      final List<int> archiveBytes = await File(archivePath).readAsBytes();

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) async {
              return http.StreamedResponse(
                Stream<List<int>>.value(archiveBytes),
                200,
              );
            },
          ),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(
          shouldPass: true,
          error: StateError('checksum read failed'),
        ),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.checksumFailed));
      expect(
        await File('$installRoot/bin/sesori-bridge').readAsString(),
        equals('old-binary'),
      );
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('download timeout returns networkError', () async {
      final String installRoot = await _createInstallRoot(
        rootTempDir: rootTempDir,
        binaryContent: 'old-binary',
      );

      final UpdateInstallerService updater = _makeUpdater(
        downloadApi: UpdateDownloadApi(
          httpClient: FakeUpdateHttpClient(
            handler: (http.BaseRequest request) {
              return Completer<http.StreamedResponse>().future;
            },
          ),
          requestTimeout: const Duration(milliseconds: 20),
        ),
        checksumManifestApi: FakeChecksumManifestApi.single(
          fileName: 'bridge.tar.gz',
          checksum: 'expected',
        ),
        checksumVerifierApi: FakeChecksumVerifierApi(shouldPass: true),
      );

      final UpdateResult result = await updater.performUpdate(
        release: ReleaseInfo(
          version: '1.2.3',
          assetUrl: 'https://example.com/bridge.tar.gz',
          checksumsUrl: 'https://example.com/checksums.txt',
          publishedAt: DateTime(2024),
        ),
        installRoot: installRoot,
      );

      expect(result, equals(UpdateResult.networkError));
      await _expectNoTempArtifacts(installRoot: installRoot);
    });

    test('windows apply script waits for unlock instead of fixed sleep', () async {
      final String installRoot = '${rootTempDir.path}/windows-install';
      final String stagingPath = '$installRoot/.sesori-bridge-staging';
      await Directory(installRoot).create(recursive: true);
      await Directory(stagingPath).create(recursive: true);

      final replacementApi = FileReplacementApi(processRunner: FakeProcessRunner(exitCode: 0));
      final pendingWindowsUpdate = PendingWindowsUpdate(
        installRoot: installRoot,
        stagingPath: stagingPath,
        archivePath: '$installRoot/.sesori-bridge-update.zip',
        lockPath: '$installRoot/.update.lock',
      );

      final String scriptPath = await replacementApi.createWindowsSwapScript(
        pending: pendingWindowsUpdate,
        args: ['--relay', 'wss://relay'],
      );
      final String script = await File(scriptPath).readAsString();

      expect(script, contains('function Wait-ForUnlockedFile'));
      expect(script, contains(r'Wait-ForUnlockedFile -Path $binaryPath -TimeoutSeconds 30'));
      expect(script, isNot(contains('Start-Sleep -Seconds 2')));
      expect(script, contains(r'Start-Process -FilePath $binaryPath -ArgumentList $args'));
      expect(script, contains(r"if (Test-Path $lockPath) { Remove-Item -Force $lockPath }"));
      expect(script, contains(r"if (Test-Path $stagingRoot) { Remove-Item -Recurse -Force $stagingRoot }"));
      expect(script, contains("'--relay', 'wss://relay'"));
      expect(scriptPath, equals('$installRoot/.sesori-bridge-apply-update.ps1'));
    });
  });

  group('UpdateService managed install gating', () {
    test('skips startup self-update when launched from unmanaged path', () async {
      final repository = _FakeReleaseRepository();
      final updater = _FakeUpdateInstallerService();
      final service = UpdateService(
        releaseRepository: repository,
        updateInstallerService: updater,
        executablePath: '/tmp/custom/bridge',
        managedExecutablePath: '/Users/alex/.sesori/bin/sesori-bridge',
        environment: const {},
      );
      service.hasTerminal = () => false;

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(0));
      expect(updater.performUpdateCallCount, equals(0));
    });

    test('checks for updates when already running the managed binary', () async {
      final repository = _FakeReleaseRepository()..onCheckForNewerRelease = () async => null;
      final updater = _FakeUpdateInstallerService();
      final service = UpdateService(
        releaseRepository: repository,
        updateInstallerService: updater,
        executablePath: '/Users/alex/.sesori/bin/sesori-bridge',
        managedExecutablePath: '/Users/alex/.sesori/bin/sesori-bridge',
        environment: const {},
      );
      service.hasTerminal = () => false;

      await service.checkAndApplyUpdate(cliArgs: const []);

      expect(repository.checkCallCount, equals(1));
    });
  });

  group('ChecksumManifestApi timeouts', () {
    test('manifest fetch times out instead of hanging indefinitely', () async {
      final checksumManifestApi = ChecksumManifestApi(
        httpClient: _NeverCompletesHttpClient(),
        requestTimeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        checksumManifestApi.fetchManifest(url: 'https://example.com/checksums.txt'),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}

class _NeverCompletesHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return Completer<http.Response>().future;
  }
}

UpdateInstallerService _makeUpdater({
  required UpdateDownloadApi downloadApi,
  required ChecksumManifestApi checksumManifestApi,
  required ChecksumVerifierApi checksumVerifierApi,
  ProcessRunner? processRunner,
  FileReplacementApi? fileReplacementApi,
}) {
  final runner = processRunner ?? ProcessRunner();
  return UpdateInstallerService(
    updateArtifactRepository: UpdateArtifactRepository(
      downloadApi: downloadApi,
      checksumManifestApi: checksumManifestApi,
      checksumVerifierApi: checksumVerifierApi,
      archiveExtractorApi: ArchiveExtractorApi(processRunner: runner),
    ),
    updateLock: UpdateLock(
      currentPid: pid,
      processRunner: runner,
    ),
    installedFileRepository: InstalledFileRepository(
      fileReplacementApi: fileReplacementApi ?? FileReplacementApi(processRunner: runner),
    ),
  );
}

Future<String> _createInstallRoot({
  required Directory rootTempDir,
  required String binaryContent,
}) async {
  final String installRoot = '${rootTempDir.path}/install';
  await Directory('$installRoot/bin').create(recursive: true);
  await File('$installRoot/bin/sesori-bridge').writeAsString(binaryContent);
  return installRoot;
}

Future<String> _createTarGzArchive({
  required Directory rootTempDir,
  required String binaryContent,
  required bool includeLib,
}) async {
  final Directory sourceDir = Directory('${rootTempDir.path}/release_source');
  if (sourceDir.existsSync()) {
    await sourceDir.delete(recursive: true);
  }

  await Directory('${sourceDir.path}/bin').create(recursive: true);
  await File('${sourceDir.path}/bin/sesori-bridge').writeAsString(binaryContent);

  if (includeLib) {
    await Directory('${sourceDir.path}/lib').create(recursive: true);
    await File('${sourceDir.path}/lib/libsqlite3.dylib').writeAsString('new-lib');
  }

  final String archivePath = '${rootTempDir.path}/release.tar.gz';
  final ProcessResult tarResult = await Process.run(
    'tar',
    ['-czf', archivePath, '-C', sourceDir.path, '.'],
  );
  if (tarResult.exitCode != 0) {
    throw StateError('Failed creating test archive: ${tarResult.stderr}');
  }

  return archivePath;
}

Future<void> _expectNoTempArtifacts({required String installRoot}) async {
  expect(File('$installRoot/.update.lock').existsSync(), isFalse);
  expect(File('$installRoot/.sesori-bridge-update.tar.gz').existsSync(), isFalse);
  expect(File('$installRoot/.sesori-bridge-update.zip').existsSync(), isFalse);
  expect(Directory('$installRoot/.sesori-bridge-staging').existsSync(), isFalse);
}
