import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("BinaryDownloadClient.download status classification", () {
    Future<void> downloadWithStatus(int status) {
      final client = MockClient((_) async => http.Response("", status));
      return BinaryDownloadClient(httpClient: client)
          .download(
            url: "https://example.test/asset.tar.gz",
            destinationPath: "/tmp/should-not-be-written",
          )
          .drain<void>();
    }

    for (final status in [500, 502, 503, 504, 429, 408]) {
      test("HTTP $status -> network failure (retryable, quiet)", () async {
        await expectLater(
          downloadWithStatus(status),
          throwsA(
            isA<DownloadException>().having((e) => e.kind, "kind", DownloadFailureKind.network),
          ),
        );
      });
    }

    for (final status in [400, 401, 403, 404]) {
      test("HTTP $status -> genuine failure", () async {
        await expectLater(
          downloadWithStatus(status),
          throwsA(
            isA<DownloadException>().having((e) => e.kind, "kind", DownloadFailureKind.failed),
          ),
        );
      });
    }
  });

  test("a 200 with a streamed body is written to disk and reports progress", () async {
    final tempDir = await Directory.systemTemp.createTemp("binary-download-client");
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final destination = p.join(tempDir.path, "asset.tar.gz");

    final client = MockClient((_) async => http.Response("payload-bytes", 200));
    final progress = await BinaryDownloadClient(httpClient: client)
        .download(url: "https://example.test/asset.tar.gz", destinationPath: destination)
        .toList();

    expect(File(destination).readAsStringSync(), equals("payload-bytes"));
    expect(progress, isNotEmpty);
    expect(progress.last.receivedBytes, equals("payload-bytes".length));
    expect(progress.last.totalBytes, equals("payload-bytes".length));
    expect(progress.last.fraction, equals(1.0));
  });

  test("a ClientException while streaming the body -> network failure (retryable)", () async {
    final tempDir = await Directory.systemTemp.createTemp("binary-download-client");
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    // 200 OK, but the response body stream resets mid-download.
    final client = _StreamErrorClient(http.ClientException("connection reset"));
    await expectLater(
      BinaryDownloadClient(httpClient: client)
          .download(
            url: "https://example.test/asset.tar.gz",
            destinationPath: p.join(tempDir.path, "asset.tar.gz"),
          )
          .drain<void>(),
      throwsA(
        isA<DownloadException>().having((e) => e.kind, "kind", DownloadFailureKind.network),
      ),
    );
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
