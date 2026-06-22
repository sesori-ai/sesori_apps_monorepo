import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/updater/foundation/filesystem_cleaner.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/models/update_result.dart';
import 'package:sesori_bridge/src/updater/repositories/update_artifact_repository.dart';
import 'package:sesori_bridge/src/updater/services/update_install_service.dart';
import 'package:test/test.dart';

class _FakeArtifactRepository implements UpdateArtifactRepository {
  UpdateResult downloadResult = UpdateResult.success;
  bool checksumValid = true;
  bool extracted = true;

  @override
  Future<UpdateResult> downloadArchive({required ReleaseInfo release, required String archivePath}) async {
    if (downloadResult == UpdateResult.success) {
      File(archivePath).writeAsStringSync('archive-bytes');
    }
    return downloadResult;
  }

  @override
  Future<bool> verifyDownloadedArchive({required ReleaseInfo release, required String archivePath}) async {
    return checksumValid;
  }

  @override
  Future<bool> extractArchive({required String archivePath, required String stagingPath}) async {
    if (extracted) {
      Directory(stagingPath).createSync(recursive: true);
    }
    return extracted;
  }
}

ReleaseInfo _release() => ReleaseInfo(
  version: '2.0.0',
  assetUrl: 'https://example.com/bridge.tar.gz',
  checksumsUrl: 'https://example.com/checksums.txt',
  publishedAt: DateTime.utc(2026),
);

void main() {
  late Directory installRoot;

  setUp(() async {
    installRoot = await Directory.systemTemp.createTemp('update-install-service');
  });

  tearDown(() async {
    if (installRoot.existsSync()) {
      await installRoot.delete(recursive: true);
    }
  });

  test('stages successfully and returns the staging path, cleaning the archive', () async {
    final service = UpdateInstallService(
      updateArtifactRepository: _FakeArtifactRepository(),
      filesystemCleaner: const FilesystemCleaner(),
    );

    final result = await service.stageUpdate(release: _release(), installRoot: installRoot.path);

    expect(result.result, UpdateResult.success);
    expect(result.stagingPath, p.join(installRoot.path, '.sesori-bridge-staging'));
    expect(Directory(result.stagingPath!).existsSync(), isTrue);
    // The archive is removed; the staging directory is kept for the apply step.
    expect(
      File(p.join(installRoot.path, '.sesori-bridge-update.tar.gz')).existsSync(),
      isFalse,
    );
  });

  test('download failure returns the failure result and no staging path', () async {
    final service = UpdateInstallService(
      updateArtifactRepository: _FakeArtifactRepository()..downloadResult = UpdateResult.networkError,
      filesystemCleaner: const FilesystemCleaner(),
    );

    final result = await service.stageUpdate(release: _release(), installRoot: installRoot.path);

    expect(result.result, UpdateResult.networkError);
    expect(result.stagingPath, isNull);
  });

  test('checksum mismatch returns checksumFailed', () async {
    final service = UpdateInstallService(
      updateArtifactRepository: _FakeArtifactRepository()..checksumValid = false,
      filesystemCleaner: const FilesystemCleaner(),
    );

    final result = await service.stageUpdate(release: _release(), installRoot: installRoot.path);

    expect(result.result, UpdateResult.checksumFailed);
    expect(result.stagingPath, isNull);
  });

  test('a non-writable install root returns permissionDenied', () async {
    if (Platform.isWindows) {
      return; // relies on POSIX read-only directory semantics
    }
    await Process.run('chmod', ['555', installRoot.path]);
    addTearDown(() => Process.run('chmod', ['755', installRoot.path]));

    final service = UpdateInstallService(
      updateArtifactRepository: _FakeArtifactRepository(),
      filesystemCleaner: const FilesystemCleaner(),
    );

    final result = await service.stageUpdate(release: _release(), installRoot: installRoot.path);

    expect(result.result, UpdateResult.permissionDenied);
    expect(result.stagingPath, isNull);
  });

  test('extraction failure returns downloadFailed and cleans staging', () async {
    final service = UpdateInstallService(
      updateArtifactRepository: _FakeArtifactRepository()..extracted = false,
      filesystemCleaner: const FilesystemCleaner(),
    );

    final result = await service.stageUpdate(release: _release(), installRoot: installRoot.path);

    expect(result.result, UpdateResult.downloadFailed);
    expect(result.stagingPath, isNull);
    expect(Directory(p.join(installRoot.path, '.sesori-bridge-staging')).existsSync(), isFalse);
  });
}
