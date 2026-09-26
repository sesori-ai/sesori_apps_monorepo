import "dart:async";
import "dart:convert";
import "dart:io";

import "package:opencode_plugin/src/sse/sse_connection.dart";
import "package:test/test.dart";

void main() {
  for (final stopDuringCallback in [false, true]) {
    test("awaits callbacks, isolates failures and fences stop=$stopDuringCallback", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final entered = Completer<void>();
      final release = Completer<void>();
      final finished = Completer<void>();
      final last = Completer<void>();
      final seen = <String>[];
      final subscription = server.listen((request) async {
        request.response.bufferOutput = false;
        request.response.headers.set(HttpHeaders.contentTypeHeader, "text/event-stream");
        request.response.write("data: first\n\ndata: fail\n\ndata: last\n");
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      final connection = SseConnection(
        targetUrl: "http://127.0.0.1:${server.port}",
        eventPath: "/api/event",
        password: null,
        onEvent: (data) async {
          seen.add(data);
          if (data == "first") {
            entered.complete();
            await release.future;
            finished.complete();
          }
          if (data == "fail") throw StateError("Fixture callback failure");
          if (data == "last") last.complete();
        },
      );
      addTearDown(connection.stop);
      connection.start(recoverOnFirstConnect: false);
      await entered.future.timeout(const Duration(seconds: 5));
      expect(seen, ["first"]);
      if (stopDuringCallback) connection.stop();
      release.complete();
      await finished.future;
      if (stopDuringCallback) {
        await pumpEventQueue();
      } else {
        await last.future.timeout(const Duration(seconds: 5));
      }
      expect(seen, stopDuringCallback ? ["first"] : ["first", "fail", "last"]);
    });
  }

  test("reconnect refresh completes before buffered events are delivered", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final refreshing = Completer<void>();
    final release = Completer<void>();
    final delivered = Completer<void>();
    final order = <String>[];
    var connections = 0;
    final subscription = server.listen((request) async {
      request.response.bufferOutput = false;
      request.response.headers.set(HttpHeaders.contentTypeHeader, "text/event-stream");
      request.response.write("data: ${++connections}\n\n");
      await request.response.flush();
      if (connections == 1) await request.response.close();
    });
    addTearDown(subscription.cancel);
    final connection = SseConnection(
      targetUrl: "http://127.0.0.1:${server.port}",
      eventPath: "/api/event",
      password: null,
      onEvent: (data) {
        order.add(data);
        if (data == "2") delivered.complete();
      },
      onReconnect: () async {
        order.add("refresh");
        refreshing.complete();
        await release.future;
        order.add("ready");
      },
    );
    addTearDown(connection.stop);
    connection.start(recoverOnFirstConnect: false);
    await refreshing.future.timeout(const Duration(seconds: 5));
    expect(order, ["1", "refresh"]);
    release.complete();
    await delivered.future.timeout(const Duration(seconds: 5));
    expect(order, ["1", "refresh", "ready", "2"]);
  });

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
