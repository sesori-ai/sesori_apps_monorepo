import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sesori_bridge/src/updater/api/checksum_manifest_api.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
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
  group('ChecksumManifestApi.fetchManifest status classification', () {
    Future<dynamic> fetchWithStatus(int status, {String body = ''}) {
      final client = MockClient((_) async => http.Response(body, status));
      return ChecksumManifestApi(httpClient: client).fetchManifest(url: 'https://example.test/checksums.txt');
    }

    for (final status in [500, 502, 503, 504, 429, 408]) {
      test('HTTP $status → throws HttpException (retryable, propagates as network error)', () async {
        await expectLater(fetchWithStatus(status), throwsA(isA<HttpException>()));
      });
    }

    test('HTTP 404 → null (genuine missing manifest, no throw)', () async {
      expect(await fetchWithStatus(404), isNull);
    });

    test('HTTP 200 → parsed manifest', () async {
      final manifest = await fetchWithStatus(
        200,
        body: '${'a' * 64}  sesori-bridge.tar.gz\n',
      );
      expect(manifest, isNotNull);
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
        final actualHash = await ChecksumValidator().computeSha256(filePath: testFile.path);
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
        final actualHash = await ChecksumValidator().computeSha256(filePath: testFile.path);
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
