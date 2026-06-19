import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sesori_bridge/src/updater/api/update_download_api.dart';
import 'package:sesori_bridge/src/updater/models/update_result.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateDownloadApi.downloadTo status classification', () {
    Future<UpdateResult> downloadWithStatus(int status) {
      final client = MockClient((_) async => http.Response('', status));
      return UpdateDownloadApi(httpClient: client).downloadTo(
        url: 'https://example.test/asset.tar.gz',
        destinationPath: '/tmp/should-not-be-written',
      );
    }

    for (final status in [500, 502, 503, 504, 429, 408]) {
      test('HTTP $status → networkError (retryable, quiet)', () async {
        expect(await downloadWithStatus(status), equals(UpdateResult.networkError));
      });
    }

    for (final status in [400, 401, 403, 404]) {
      test('HTTP $status → downloadFailed (genuine)', () async {
        expect(await downloadWithStatus(status), equals(UpdateResult.downloadFailed));
      });
    }
  });
}
