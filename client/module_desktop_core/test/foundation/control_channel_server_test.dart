import "dart:async";
import "dart:io";

import "package:rxdart/rxdart.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

Future<WebSocket> connectHelper(ControlChannelServer server, {String? secret}) {
  return WebSocket.connect(
    server.url.toString(),
    headers: <String, dynamic>{"Authorization": "Bearer ${secret ?? server.secret}"},
  );
}

void main() {
  late ControlChannelServer server;

  setUp(() async {
    server = ControlChannelServer();
    await server.start();
    addTearDown(server.dispose);
  });

  test("binds an ephemeral loopback port and mints a secret", () {
    expect(server.url.host, "127.0.0.1");
    expect(server.url.port, greaterThan(0));
    expect(server.secret, isNotEmpty);
  });

  test("each start mints a fresh secret", () async {
    final String first = server.secret;
    await server.stop();

    await server.start();

    expect(server.secret, isNot(first));
  });

  test("rejects a connection with a wrong secret", () async {
    await expectLater(connectHelper(server, secret: "wrong"), throwsA(isA<WebSocketException>()));
    expect(server.helperConnectionStream.value, isFalse);
  });

  test("rejects a plain HTTP request without an upgrade", () async {
    final HttpClient client = HttpClient();
    addTearDown(client.close);
    final HttpClientRequest request = await client.getUrl(
      Uri.parse("http://127.0.0.1:${server.url.port}/"),
    );
    request.headers.set(HttpHeaders.authorizationHeader, "Bearer ${server.secret}");

    final HttpClientResponse response = await request.close();

    expect(response.statusCode, HttpStatus.badRequest);
  });

  test("accepts the helper and delivers inbound text frames", () async {
    final Future<ControlChannelFrame> firstFrame = server.events.whereType<ControlChannelFrame>().first;
    final WebSocket helper = await connectHelper(server);
    addTearDown(helper.close);

    helper.add('{"type":"status"}');

    expect((await firstFrame).text, '{"type":"status"}');
    expect(server.helperConnectionStream.value, isTrue);
  });

  test("lifecycle and frames arrive on one stream in true socket order", () async {
    final List<ControlChannelEvent> events = <ControlChannelEvent>[];
    final StreamSubscription<ControlChannelEvent> subscription = server.events.listen(events.add);
    addTearDown(subscription.cancel);

    final WebSocket helper = await connectHelper(server);
    helper.add("first");
    helper.add("second");
    await helper.close();
    await server.helperConnectionStream.firstWhere((connected) => !connected);
    await pumpEventQueue();

    expect(events, hasLength(4));
    expect(events[0], isA<ControlChannelConnected>());
    expect(events[1], isA<ControlChannelFrame>().having((frame) => frame.text, "text", "first"));
    expect(events[2], isA<ControlChannelFrame>().having((frame) => frame.text, "text", "second"));
    expect(events[3], isA<ControlChannelDisconnected>());
  });

  test("send delivers a frame to the connected helper", () async {
    final WebSocket helper = await connectHelper(server);
    addTearDown(helper.close);
    final Future<Object?> received = helper.first;
    // Wait for the server side to finish attaching the socket.
    await server.helperConnectionStream.firstWhere((connected) => connected);

    server.send("hello");

    expect(await received, "hello");
  });

  test("send without a connected helper throws the typed exception", () {
    expect(() => server.send("x"), throwsA(isA<ControlHelperNotConnectedException>()));
  });

  test("rejects a concurrent second helper while one is connected", () async {
    final WebSocket helper = await connectHelper(server);
    addTearDown(helper.close);
    await server.helperConnectionStream.firstWhere((connected) => connected);

    await expectLater(connectHelper(server), throwsA(isA<WebSocketException>()));
  });

  test("accepts a reconnect after the helper drops", () async {
    final WebSocket helper = await connectHelper(server);
    await server.helperConnectionStream.firstWhere((connected) => connected);

    await helper.close();
    await server.helperConnectionStream.firstWhere((connected) => !connected);

    final WebSocket reconnected = await connectHelper(server);
    addTearDown(reconnected.close);
    await server.helperConnectionStream.firstWhere((connected) => connected);
    expect(server.helperConnectionStream.value, isTrue);
  });

  test("two concurrent authenticated upgrades leave exactly one active helper", () async {
    final List<WebSocket> connected = <WebSocket>[];
    // Fire both connects in the same event-loop turn so their upgrades race.
    final List<Object?> results = await Future.wait(<Future<Object?>>[
      connectHelper(server).then<Object?>((socket) {
        connected.add(socket);
        return socket;
      }).catchError((Object error) => error),
      connectHelper(server).then<Object?>((socket) {
        connected.add(socket);
        return socket;
      }).catchError((Object error) => error),
    ]);
    for (final WebSocket socket in connected) {
      addTearDown(socket.close);
    }

    // Either the loser was 409'd pre-upgrade, or it was closed post-upgrade
    // by the slot re-validation — both ways exactly one helper survives.
    if (connected.length == 2) {
      final List<Future<Object?>> dones = connected.map((socket) => socket.done).toList();
      await Future.any(dones);
    } else {
      expect(results.whereType<WebSocketException>(), hasLength(1));
    }
    expect(server.helperConnectionStream.value, isTrue);
    final int openCount = connected.where((socket) => socket.readyState == WebSocket.open).length;
    expect(openCount, 1);
  });

  test("stop closes the server and reports the helper disconnected", () async {
    final WebSocket helper = await connectHelper(server);
    addTearDown(helper.close);
    await server.helperConnectionStream.firstWhere((connected) => connected);

    await server.stop();

    expect(server.helperConnectionStream.value, isFalse);
    expect(() => server.url, throwsStateError);
    expect(() => server.secret, throwsStateError);
  });
}
