import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
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

  test('a 200 with a streamed body is written to disk and returns success', () async {
    final tempDir = await Directory.systemTemp.createTemp('update-download-api');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final destination = p.join(tempDir.path, 'asset.tar.gz');

    final client = MockClient((_) async => http.Response('payload-bytes', 200));
    final result = await UpdateDownloadApi(httpClient: client).downloadTo(
      url: 'https://example.test/asset.tar.gz',
      destinationPath: destination,
    );

    expect(result, equals(UpdateResult.success));
    expect(File(destination).readAsStringSync(), equals('payload-bytes'));
  });

  test('a ClientException while streaming the body → networkError (retryable)', () async {
    final tempDir = await Directory.systemTemp.createTemp('update-download-api');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    // 200 OK, but the response body stream resets mid-download.
    final client = _StreamErrorClient(http.ClientException('connection reset'));
    final result = await UpdateDownloadApi(httpClient: client).downloadTo(
      url: 'https://example.test/asset.tar.gz',
      destinationPath: p.join(tempDir.path, 'asset.tar.gz'),
    );

    expect(result, equals(UpdateResult.networkError));
  });
}

/// Returns a 2xx [http.StreamedResponse] whose body stream immediately errors,
/// simulating a connection reset after the response headers arrive.
class _StreamErrorClient extends http.BaseClient {
  _StreamErrorClient(this._streamError);

  final Object _streamError;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();
    controller.addError(_streamError);
    unawaited(controller.close());
    return http.StreamedResponse(controller.stream, 200);
  }
}
