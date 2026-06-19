import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sesori_bridge/src/updater/api/checksum_manifest_api.dart';
import 'package:test/test.dart';

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
}
