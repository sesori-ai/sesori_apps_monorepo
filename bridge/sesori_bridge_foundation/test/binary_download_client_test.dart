import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
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

  test("an unwritable destination fails the download instead of crashing the isolate", () async {
    final tempDir = await Directory.systemTemp.createTemp("binary-download-client");
    addTearDown(() async {
      if (tempDir.existsSync()) {
        final destination = File(p.join(tempDir.path, "asset.tar.gz"));
        if (destination.existsSync()) Process.runSync("chmod", ["600", destination.path]);
        await tempDir.delete(recursive: true);
      }
    });
    final destination = p.join(tempDir.path, "asset.tar.gz");
    // Read-only, matching a managed runtime directory the bridge cannot write.
    File(destination).writeAsStringSync("");
    Process.runSync("chmod", ["400", destination]);

    // Several chunks with real gaps between them: a single-chunk body would
    // surface the failure from the awaited close() and hide the defect. An
    // IOSink defers its open to the first write, so with more writes in flight
    // the open error escaped as an unhandled asynchronous error and terminated
    // the bridge process instead of failing this download.
    Stream<List<int>> body() async* {
      for (var chunk = 0; chunk < 5; chunk++) {
        yield List<int>.filled(1024, 7);
        await Future<void>.delayed(Duration.zero);
      }
    }

    final client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(body(), 200, contentLength: 5 * 1024),
    );
    final download = BinaryDownloadClient(httpClient: client)
        .download(url: "https://example.test/asset.tar.gz", destinationPath: destination)
        .toList();

    await expectLater(
      download,
      throwsA(
        isA<DownloadException>().having((error) => error.kind, "kind", DownloadFailureKind.failed),
      ),
    );
  }, skip: Platform.isWindows ? "POSIX permission bits do not gate writes on Windows" : null);

  test("a connection-phase failure is wrapped as a network DownloadException", () async {
    final client = _SendErrorClient(const SocketException("connection refused"));
    await expectLater(
      BinaryDownloadClient(httpClient: client)
          .download(url: "https://example.test/asset.tar.gz", destinationPath: "/tmp/should-not-be-written")
          .drain<void>(),
      throwsA(isA<DownloadException>().having((e) => e.kind, "kind", DownloadFailureKind.network)),
    );
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
class _StreamErrorClient(final Object _streamError) extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();
    controller.addError(_streamError);
    unawaited(controller.close());
    return http.StreamedResponse(controller.stream, 200);
  }
}

/// Throws from `send`, simulating a connection-phase transport failure (before
/// any response headers arrive).
class _SendErrorClient(final Object _sendError) extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw _sendError;
  }
}
