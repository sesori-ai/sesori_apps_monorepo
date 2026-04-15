import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/updater/api/checksum_manifest_api.dart';
import 'package:sesori_bridge/src/updater/api/checksum_verifier_api.dart';
import 'package:test/test.dart';

class FakeHttpClient extends http.BaseClient {
  final Map<String, http.Response> responses = {};
  Object? error;
  int sendCallCount = 0;

  void setResponse(String url, http.Response response) {
    responses[url] = response;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCallCount++;
    if (error != null) {
      throw error!;
    }
    final response = responses[request.url.toString()];
    if (response == null) {
      return http.StreamedResponse(
        Stream.value([]),
        404,
      );
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('ChecksumVerifierApi', () {
    late ChecksumVerifierApi verifier;

    setUp(() {
      verifier = ChecksumVerifierApi();
    });

    test('verify returns true for matching checksum', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File('${tempDir.path}/test-binary.tar.gz');
      await testFile.writeAsString('test content');

      try {
        final actualHash = await verifier.computeSha256(filePath: testFile.path);

        final result = await verifier.verify(
          filePath: testFile.path,
          expectedHash: actualHash,
        );

        expect(result, isTrue);
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test('verify returns false for tampered file', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File('${tempDir.path}/test-binary.tar.gz');
      await testFile.writeAsString('test content');

      try {
        const wrongHash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

        final result = await verifier.verify(
          filePath: testFile.path,
          expectedHash: wrongHash,
        );

        expect(result, isFalse);
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test('verify returns false when file does not exist', () async {
      final result = await verifier.verify(
        filePath: '/nonexistent/path/nonexistent.tar.gz',
        expectedHash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );

      expect(result, isFalse);
    });

    test('verify handles case-insensitive hex comparison', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File('${tempDir.path}/test-binary.tar.gz');
      await testFile.writeAsString('test content');

      try {
        final actualHash = await verifier.computeSha256(filePath: testFile.path);
        final uppercaseHash = actualHash.toUpperCase();

        final result = await verifier.verify(
          filePath: testFile.path,
          expectedHash: uppercaseHash,
        );

        expect(result, isTrue);
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test('computeSha256 returns lowercase hex string', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File('${tempDir.path}/test-binary.tar.gz');
      await testFile.writeAsString('test content');

      try {
        final hash = await verifier.computeSha256(filePath: testFile.path);

        expect(hash, matches(RegExp(r'^[a-f0-9]{64}$')));

        final expectedHash = sha256.convert('test content'.codeUnits).toString();
        expect(hash, equals(expectedHash));
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });
  });

  group('ChecksumManifestApi', () {
    late FakeHttpClient fakeHttpClient;
    late ChecksumManifestApi checksumManifestApi;

    setUp(() {
      fakeHttpClient = FakeHttpClient();
      checksumManifestApi = ChecksumManifestApi(httpClient: fakeHttpClient);
    });

    test('parses multiple entries', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File('${tempDir.path}/sesori-bridge-macos-arm64.tar.gz');
      await testFile.writeAsString('test content');

      try {
        final actualHash = await ChecksumVerifierApi().computeSha256(filePath: testFile.path);
        final checksumsContent =
            '''
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  sesori-bridge-linux-x64.tar.gz
$actualHash  sesori-bridge-macos-arm64.tar.gz
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  sesori-bridge-windows-x64.exe
''';

        fakeHttpClient.setResponse(
          'https://example.com/checksums.txt',
          http.Response(checksumsContent, 200),
        );

        final manifest = await checksumManifestApi.fetchManifest(
          url: 'https://example.com/checksums.txt',
        );

        expect(
          manifest?.checksumForFileName(fileName: 'sesori-bridge-macos-arm64.tar.gz'),
          equals(actualHash),
        );
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test('ignores empty lines', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File('${tempDir.path}/test-binary.tar.gz');
      await testFile.writeAsString('test content');

      try {
        final actualHash = await ChecksumVerifierApi().computeSha256(filePath: testFile.path);
        final checksumsContent =
            '''

$actualHash  test-binary.tar.gz

''';

        fakeHttpClient.setResponse(
          'https://example.com/checksums.txt',
          http.Response(checksumsContent, 200),
        );

        final manifest = await checksumManifestApi.fetchManifest(
          url: 'https://example.com/checksums.txt',
        );

        expect(
          manifest?.checksumForFileName(fileName: 'test-binary.tar.gz'),
          equals(actualHash),
        );
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test('returns null when download fails', () async {
      fakeHttpClient.setResponse(
        'https://example.com/checksums.txt',
        http.Response('Not Found', 404),
      );

      final manifest = await checksumManifestApi.fetchManifest(
        url: 'https://example.com/checksums.txt',
      );

      expect(manifest, isNull);
    });

    test('throws when http client fails unexpectedly', () async {
      fakeHttpClient.error = StateError('boom');

      await expectLater(
        checksumManifestApi.fetchManifest(url: 'https://example.com/checksums.txt'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
