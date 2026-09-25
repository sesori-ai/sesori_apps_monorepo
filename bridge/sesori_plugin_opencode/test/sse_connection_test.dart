import "dart:async";
import "dart:convert";
import "dart:io";

import "package:opencode_plugin/src/sse/sse_connection.dart";
import "package:test/test.dart";

void main() {
  for (final path in <String>["/global/event", "/api/event"]) {
    test("subscribes to $path with authentication and ignores heartbeat comments", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<String>();
      final requestReceived = Completer<HttpRequest>();
      final serverSubscription = server.listen((request) {
        requestReceived.complete(request);
        request.response.bufferOutput = false;
        request.response.headers.set(HttpHeaders.contentTypeHeader, "text/event-stream");
        request.response.write(': heartbeat\n\nevent: message\ndata: {"type":"fixture",\ndata: "data":{}}\n\n');
        unawaited(request.response.flush());
      });
      addTearDown(serverSubscription.cancel);
      final connection = SseConnection(
        targetUrl: "http://127.0.0.1:${server.port}",
        eventPath: path,
        password: "fixture",
        onEvent: received.complete,
      );
      addTearDown(connection.stop);
      connection.start(recoverOnFirstConnect: false);
      final request = await requestReceived.future.timeout(const Duration(seconds: 5));
      expect(request.uri.path, path);
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        "Basic ${base64.encode(utf8.encode("opencode:fixture"))}",
      );
      expect(request.headers.value(HttpHeaders.acceptHeader), "text/event-stream");
      expect(await received.future.timeout(const Duration(seconds: 5)), '{"type":"fixture",\n"data":{}}');
      await connection.firstConnected;
    });
  }
}
