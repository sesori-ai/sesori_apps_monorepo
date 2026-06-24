import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/updater/api/checksum_manifest_api.dart';
import 'package:sesori_bridge/src/updater/models/checksum_manifest.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/repositories/update_artifact_repository.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:test/test.dart';

class _FakeUpdateHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;

  _FakeUpdateHttpClient({required Future<http.StreamedResponse> Function(http.BaseRequest request) handler})
    : _handler = handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _handler(request);
}

class _FakeChecksumManifestApi implements ChecksumManifestApi {
  final ChecksumManifest? manifest;
  final Object? error;

  _FakeChecksumManifestApi({this.manifest, this.error});

  @override
  Future<ChecksumManifest?> fetchManifest({required String url}) async {
    if (error != null) {
      throw error!;
    }
    return manifest;
  }
}

class _FakeChecksumValidator implements ChecksumValidator {
  final bool result;
  final Object? error;
  String? lastExpectedHash;

  _FakeChecksumValidator({required this.result, this.error});

  @override
  Future<String> computeSha256({required String filePath}) async => 'unused';

  @override
  Future<bool> verify({required String filePath, required String expectedHash}) async {
    lastExpectedHash = expectedHash;
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

/// A no-op [CommandExecutor]: these tests exercise only checksum verification,
/// so the extractor is constructed but never invoked.
class _UnusedCommandExecutor implements CommandExecutor {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }
}

/// Builds a repository whose download/extract collaborators are inert, varying
/// only the manifest + validator that the verify-path tests care about.
UpdateArtifactRepository buildRepository({
  required ChecksumManifestApi checksumManifestApi,
  required ChecksumValidator checksumValidator,
}) {
  return UpdateArtifactRepository(
    downloadClient: BinaryDownloadClient(
      httpClient: _FakeUpdateHttpClient(
        handler: (request) async => http.StreamedResponse(const Stream.empty(), 200),
      ),
    ),
    checksumManifestApi: checksumManifestApi,
    checksumValidator: checksumValidator,
    archiveExtractor: ArchiveExtractor(commandExecutor: _UnusedCommandExecutor()),
    archiveFormat: ArchiveFormat.tarGz,
  );
}

void main() {
  group('UpdateArtifactRepository.verifyDownloadedArchive', () {
    late ReleaseInfo release;

    setUp(() {
      release = ReleaseInfo(
        version: '1.2.3',
        assetUrl: 'https://example.com/download/sesori-bridge-macos-arm64.tar.gz',
        checksumsUrl: 'https://example.com/checksums.txt',
        publishedAt: DateTime(2024),
      );
    });

    test('uses published release asset filename when resolving checksum', () async {
      final validator = _FakeChecksumValidator(result: true);
      final repository = buildRepository(
        checksumManifestApi: _FakeChecksumManifestApi(
          manifest: ChecksumManifest(
            entries: {'sesori-bridge-macos-arm64.tar.gz': 'a' * 64},
          ),
        ),
        checksumValidator: validator,
      );

      final result = await repository.verifyDownloadedArchive(
        release: release,
        archivePath: '/tmp/.sesori-bridge-update.tar.gz',
      );

      expect(result, isTrue);
      expect(validator.lastExpectedHash, equals('a' * 64));
    });

    test('returns false when manifest does not contain published asset filename', () async {
      final repository = buildRepository(
        checksumManifestApi: _FakeChecksumManifestApi(
          manifest: ChecksumManifest(entries: {'bridge.tar.gz': 'a' * 64}),
        ),
        checksumValidator: _FakeChecksumValidator(result: true),
      );

      final result = await repository.verifyDownloadedArchive(
        release: release,
        archivePath: '/tmp/.sesori-bridge-update.tar.gz',
      );

      expect(result, isFalse);
    });

    test('returns false when checksum manifest api throws', () async {
      final repository = buildRepository(
        checksumManifestApi: _FakeChecksumManifestApi(error: StateError('boom')),
        checksumValidator: _FakeChecksumValidator(result: true),
      );

      final result = await repository.verifyDownloadedArchive(
        release: release,
        archivePath: '/tmp/.sesori-bridge-update.tar.gz',
      );

      expect(result, isFalse);
    });

    test('rethrows network errors so the caller can classify them as transient', () async {
      final repository = buildRepository(
        checksumManifestApi: _FakeChecksumManifestApi(error: const SocketException('offline')),
        checksumValidator: _FakeChecksumValidator(result: true),
      );

      await expectLater(
        repository.verifyDownloadedArchive(
          release: release,
          archivePath: '/tmp/.sesori-bridge-update.tar.gz',
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('returns false when checksum validator throws', () async {
      final repository = buildRepository(
        checksumManifestApi: _FakeChecksumManifestApi(
          manifest: ChecksumManifest(
            entries: {'sesori-bridge-macos-arm64.tar.gz': 'a' * 64},
          ),
        ),
        checksumValidator: _FakeChecksumValidator(
          result: true,
          error: StateError('verify failed'),
        ),
      );

      final result = await repository.verifyDownloadedArchive(
        release: release,
        archivePath: '/tmp/.sesori-bridge-update.tar.gz',
      );

      expect(result, isFalse);
    });
  });
}
