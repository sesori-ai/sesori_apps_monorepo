import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/updater/api/archive_extractor_api.dart';
import 'package:sesori_bridge/src/updater/api/checksum_manifest_api.dart';
import 'package:sesori_bridge/src/updater/api/checksum_verifier_api.dart';
import 'package:sesori_bridge/src/updater/api/update_download_api.dart';
import 'package:sesori_bridge/src/updater/models/checksum_manifest.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/repositories/update_artifact_repository.dart';
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

class _FakeChecksumVerifierApi implements ChecksumVerifierApi {
  final bool result;
  final Object? error;
  String? lastExpectedHash;

  _FakeChecksumVerifierApi({required this.result, this.error});

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

class _FakeProcessRunner implements ProcessRunner {
  final int exitCode;

  _FakeProcessRunner({required this.exitCode});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return ProcessResult(1, exitCode, '', '');
  }
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
      final verifier = _FakeChecksumVerifierApi(result: true);
      final repository = UpdateArtifactRepository(
        downloadApi: UpdateDownloadApi(
          httpClient: _FakeUpdateHttpClient(
            handler: (request) async => http.StreamedResponse(const Stream.empty(), 200),
          ),
        ),
        checksumManifestApi: _FakeChecksumManifestApi(
          manifest: ChecksumManifest(
            entries: {'sesori-bridge-macos-arm64.tar.gz': 'a' * 64},
          ),
        ),
        checksumVerifierApi: verifier,
        archiveExtractorApi: ArchiveExtractorApi(processRunner: _FakeProcessRunner(exitCode: 0)),
      );

      final result = await repository.verifyDownloadedArchive(
        release: release,
        archivePath: '/tmp/.sesori-bridge-update.tar.gz',
      );

      expect(result, isTrue);
      expect(verifier.lastExpectedHash, equals('a' * 64));
    });

    test('returns false when manifest does not contain published asset filename', () async {
      final repository = UpdateArtifactRepository(
        downloadApi: UpdateDownloadApi(
          httpClient: _FakeUpdateHttpClient(
            handler: (request) async => http.StreamedResponse(const Stream.empty(), 200),
          ),
        ),
        checksumManifestApi: _FakeChecksumManifestApi(
          manifest: ChecksumManifest(entries: {'bridge.tar.gz': 'a' * 64}),
        ),
        checksumVerifierApi: _FakeChecksumVerifierApi(result: true),
        archiveExtractorApi: ArchiveExtractorApi(processRunner: _FakeProcessRunner(exitCode: 0)),
      );

      final result = await repository.verifyDownloadedArchive(
        release: release,
        archivePath: '/tmp/.sesori-bridge-update.tar.gz',
      );

      expect(result, isFalse);
    });

    test('returns false when checksum manifest api throws', () async {
      final repository = UpdateArtifactRepository(
        downloadApi: UpdateDownloadApi(
          httpClient: _FakeUpdateHttpClient(
            handler: (request) async => http.StreamedResponse(const Stream.empty(), 200),
          ),
        ),
        checksumManifestApi: _FakeChecksumManifestApi(error: StateError('boom')),
        checksumVerifierApi: _FakeChecksumVerifierApi(result: true),
        archiveExtractorApi: ArchiveExtractorApi(processRunner: _FakeProcessRunner(exitCode: 0)),
      );

      final result = await repository.verifyDownloadedArchive(
        release: release,
        archivePath: '/tmp/.sesori-bridge-update.tar.gz',
      );

      expect(result, isFalse);
    });

    test('returns false when checksum verifier throws', () async {
      final repository = UpdateArtifactRepository(
        downloadApi: UpdateDownloadApi(
          httpClient: _FakeUpdateHttpClient(
            handler: (request) async => http.StreamedResponse(const Stream.empty(), 200),
          ),
        ),
        checksumManifestApi: _FakeChecksumManifestApi(
          manifest: ChecksumManifest(
            entries: {'sesori-bridge-macos-arm64.tar.gz': 'a' * 64},
          ),
        ),
        checksumVerifierApi: _FakeChecksumVerifierApi(
          result: true,
          error: StateError('verify failed'),
        ),
        archiveExtractorApi: ArchiveExtractorApi(processRunner: _FakeProcessRunner(exitCode: 0)),
      );

      final result = await repository.verifyDownloadedArchive(
        release: release,
        archivePath: '/tmp/.sesori-bridge-update.tar.gz',
      );

      expect(result, isFalse);
    });
  });
}
