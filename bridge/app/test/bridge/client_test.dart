import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:sesori_bridge/src/foundation/relay_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  group("RelayClient", () {
    test("send prefixes payload with big-endian connID", () async {
      final (server, messageStream) = await startTestRelayServer();
      addTearDown(server.close);

      final (:client, :connection) = await connectTestRelayClient(server);
      _closeAfterTest(client: client, connection: connection);

      const tests = [
        (connID: 0, hi: 0x00, lo: 0x00),
        (connID: 3, hi: 0x00, lo: 0x03),
        (connID: 256, hi: 0x01, lo: 0x00),
        (connID: 65535, hi: 0xFF, lo: 0xFF),
      ];

      final payload = Uint8List.fromList("test-payload".codeUnits);

      for (final tt in tests) {
        expect(
          client.sendIfCurrent(
            connection: connection,
            connID: tt.connID,
            payload: payload,
          ),
          RelaySendOutcome.sent,
        );

        final msg = await messageStream.first.timeout(
          const Duration(seconds: 2),
        );
        expect(msg.length, greaterThanOrEqualTo(2));
        expect(msg[0], equals(tt.hi));
        expect(msg[1], equals(tt.lo));

        final connID = ByteData.sublistView(
          Uint8List.fromList(msg),
        ).getUint16(0);
        expect(connID, equals(tt.connID));
        expect(msg.sublist(2), equals(payload));
      }
    });

    test("send returns stale when its connection is not current", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);
      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final connection = await client.connect();
      await server.nextClient();
      await client.closeIfCurrent(connection: connection);

      expect(
        client.sendIfCurrent(
          connection: connection,
          connID: 0,
          payload: Uint8List.fromList("hello".codeUnits),
        ),
        RelaySendOutcome.stale,
      );
    });
  });

  group("RelayClient auth message", () {
    test("includes bridgeId when the provider has one", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider("jwt-token"),
        bridgeIdProvider: FakeBridgeIdProvider("br_abc12345"),
      );
      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final serverWs = await server.nextClient();
      final authJson = await _firstTextFrame(serverWs);

      expect(
        authJson,
        equals({
          "type": "auth",
          "token": "jwt-token",
          "role": "bridge",
          "bridgeId": "br_abc12345",
        }),
      );
    });

    test("omits bridgeId when the provider has none", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider("jwt-token"),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final serverWs = await server.nextClient();
      final authJson = await _firstTextFrame(serverWs);

      expect(
        authJson,
        equals({"type": "auth", "token": "jwt-token", "role": "bridge"}),
      );
    });
  });

  group("RelayClient close code", () {
    test("exposes the server's close code after the stream ends", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final serverWs = await server.nextClient();
      expect(client.closeCode(connection: connection), isNull);

      final streamDone = Completer<void>();
      client.read(connection: connection).listen((_) {}, onDone: streamDone.complete);
      await serverWs.close(RelayCloseCodes.bridgeRevoked);
      await streamDone.future.timeout(const Duration(seconds: 5));

      expect(client.closeCode(connection: connection), equals(RelayCloseCodes.bridgeRevoked));
    });

    test("exposes the server's close reason (bridge-replaced rollout fallback)", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final serverWs = await server.nextClient();
      final streamDone = Completer<void>();
      client.read(connection: connection).listen((_) {}, onDone: streamDone.complete);
      await serverWs.close(1000, "replaced");
      await streamDone.future.timeout(const Duration(seconds: 5));

      expect(client.closeCode(connection: connection), equals(1000));
      expect(client.closeReason(connection: connection), equals("replaced"));
    });
  });

  group("RelayClient connectionState", () {
    test("connect emits connecting then connected", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final statesFuture = _recordStates(
        stream: client.connectionState,
        count: 2,
      )..ignore();

      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final states = await statesFuture;
      expect(states, hasLength(2));
      expect(states[0], isA<RelayConnecting>());
      expect(states[1], isA<RelayConnected>());
    });

    test("auth setup failure emits disconnected without a false connected state", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: _ThrowingAccessTokenProvider(),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final states = <RelayConnectionState>[];
      final disconnected = Completer<void>();
      client.connectionState.listen((state) {
        states.add(state);
        if (state is RelayDisconnected && !disconnected.isCompleted) {
          disconnected.complete();
        }
      });

      await expectLater(client.connect(), throwsA(isA<StateError>()));
      await disconnected.future.timeout(const Duration(seconds: 2));
      // Drain the microtask queue so any falsely emitted connected state (or a
      // duplicate disconnected state) that would follow the first disconnected
      // one is still observed before the exact-sequence assertion.
      await pumpEventQueue();

      expect(states, hasLength(2));
      expect(states[0], isA<RelayConnecting>());
      expect(states[1], isA<RelayDisconnected>());
      expect(states.whereType<RelayConnected>(), isEmpty);
    });

    test("remote close emits disconnected carrying the close code", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final states = <RelayConnectionState>[];
      client.connectionState.listen(states.add);
      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final serverWs = await server.nextClient();
      // Drop detection requires the inbound stream to be consumed, exactly
      // like the orchestrator's relay loop does on a live connection.
      client.read(connection: connection).listen((_) {});
      final disconnected = client.connectionState.firstWhere((state) => state is RelayDisconnected);
      await serverWs.close(RelayCloseCodes.bridgeRevoked);

      final state = await disconnected.timeout(const Duration(seconds: 5)) as RelayDisconnected;
      expect(state.closeCode, equals(RelayCloseCodes.bridgeRevoked));
    });

    test("remote close carries the close reason on the disconnected state", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final states = <RelayConnectionState>[];
      client.connectionState.listen(states.add);
      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final serverWs = await server.nextClient();
      client.read(connection: connection).listen((_) {});
      final disconnected = client.connectionState.firstWhere((state) => state is RelayDisconnected);
      await serverWs.close(1000, "replaced");

      final state = await disconnected.timeout(const Duration(seconds: 5)) as RelayDisconnected;
      expect(state.closeCode, equals(1000));
      expect(state.closeReason, equals("replaced"));
    });

    test("deliberate close emits no disconnected state", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final states = <RelayConnectionState>[];
      client.connectionState.listen(states.add);
      final connection = await client.connect();
      await server.nextClient();

      expect(
        await client.closeIfCurrent(connection: connection),
        RelayCloseOutcome.closed,
      );
      // Give the sink-done watcher time to fire if it (incorrectly) would.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(states.whereType<RelayDisconnected>(), isEmpty);
    });

    test("close promptly cancels a pending WebSocket handshake without late promotion", () async {
      final rawServer = await ServerSocket.bind("127.0.0.1", 0);
      final accepted = Completer<Socket>();
      Socket? acceptedSocket;
      rawServer.listen((socket) {
        if (accepted.isCompleted) {
          socket.destroy();
          return;
        }
        acceptedSocket = socket;
        accepted.complete(socket);
      });
      addTearDown(() async {
        acceptedSocket?.destroy();
        await rawServer.close();
      });

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${rawServer.port}",
        accessTokenProvider: FakeAccessTokenProvider("jwt-token"),
        bridgeIdProvider: FakeBridgeIdProvider("br_abc12345"),
        connectTimeout: const Duration(seconds: 30),
      );
      final states = <RelayConnectionState>[];
      client.connectionState.listen(states.add);

      final connectFuture = client.connect();
      connectFuture.ignore();
      await accepted.future.timeout(const Duration(seconds: 2));

      final stopwatch = Stopwatch()..start();
      await client.cancelPendingConnection().timeout(const Duration(seconds: 5));
      stopwatch.stop();

      await expectLater(connectFuture, throwsA(anything));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(states.whereType<RelayConnected>(), isEmpty);
      expect(states.whereType<RelayDisconnected>(), isEmpty);
    });

    test("failed connect emits disconnected with no close code", () async {
      // A TCP server that accepts but never completes the WebSocket upgrade.
      final rawServer = await ServerSocket.bind("127.0.0.1", 0);
      addTearDown(rawServer.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${rawServer.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
        connectTimeout: const Duration(milliseconds: 500),
      );
      final statesFuture = _recordStates(
        stream: client.connectionState,
        count: 2,
      )..ignore();

      await expectLater(client.connect(), throwsA(isA<TimeoutException>()));
      final states = await statesFuture;

      expect(states[0], isA<RelayConnecting>());
      expect(states[1], isA<RelayDisconnected>());
      expect((states[1] as RelayDisconnected).closeCode, isNull);
    });

    test("rejected upgrade does not wait for unopened channel cleanup", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      server.listen((request) {
        request.response.statusCode = HttpStatus.tooManyRequests;
        unawaited(request.response.close());
      });
      addTearDown(() => server.close(force: true));

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final stopwatch = Stopwatch()..start();

      await expectLater(
        client.connect(),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains("429"),
          ),
        ),
      );
      stopwatch.stop();

      // The regression adds a full one-second cleanup timeout after the local
      // server has already rejected the upgrade. Allow CI scheduling slack
      // while still requiring completion before that timeout can elapse.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test("reconnect after a remote drop emits connecting then connected again", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final statesFuture = _recordStates(
        stream: client.connectionState,
        count: 5,
      )..ignore();
      var connection = await client.connect();
      addTearDown(() => client.closeIfCurrent(connection: connection));

      final serverWs1 = await server.nextClient();
      // Drop detection requires the inbound stream to be consumed, exactly
      // like the orchestrator's relay loop does on a live connection.
      client.read(connection: connection).listen((_) {});
      final disconnected = client.connectionState.firstWhere((state) => state is RelayDisconnected);
      await serverWs1.close();
      await disconnected.timeout(const Duration(seconds: 5));

      final serverWs2Future = server.nextClient();
      await client.closeIfCurrent(connection: connection);
      connection = await client.connect();
      await serverWs2Future;

      final states = await statesFuture;
      expect(
        states.map((state) => state.runtimeType).toList(),
        equals([RelayConnecting, RelayConnected, RelayDisconnected, RelayConnecting, RelayConnected]),
      );
    });
  });

  group("RelayClient reconnection", () {
    test("read stream ends when server closes connection", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final serverWs = await server.nextClient();

      final messages = <RelayClientMessage>[];
      final firstMessage = Completer<void>();
      final done = Completer<void>();

      client
          .read(connection: connection)
          .listen(
            (message) {
              messages.add(message);
              if (!firstMessage.isCompleted) firstMessage.complete();
            },
            onDone: done.complete,
            onError: done.completeError,
          );

      // Send a message and verify receipt.
      serverWs.add("hello");
      await firstMessage.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(messages, hasLength(1));

      // Close the server-side WebSocket — the client stream should end.
      await serverWs.close();

      await expectLater(
        done.future.timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test("await-for exits when server closes connection", () async {
      // This directly validates the pattern used in the orchestrator's
      // _runRelayLoop: an await-for over client.read() must exit when
      // the underlying WebSocket is closed by the remote side.
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final connection = await client.connect();
      _closeAfterTest(client: client, connection: connection);

      final serverWs = await server.nextClient();

      var messageCount = 0;
      final firstMessage = Completer<void>();
      final loopExited = Completer<void>();

      unawaited(
        (() async {
          await for (final _ in client.read(connection: connection)) {
            messageCount++;
            if (!firstMessage.isCompleted) firstMessage.complete();
          }
          loopExited.complete();
        })(),
      );

      // Deliver a message so we know the loop is running.
      serverWs.add("ping");
      await firstMessage.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(messageCount, equals(1));

      // Drop the connection from the server side.
      await serverWs.close();

      // The await-for loop must exit promptly.
      await expectLater(
        loopExited.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail("await-for loop did not exit after server close"),
        ),
        completes,
      );
    });

    test("reconnect yields working connection after server close", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      var connection = await client.connect();
      addTearDown(() => client.closeIfCurrent(connection: connection));

      final serverWs1 = await server.nextClient();

      // Verify the first connection works.
      final msgs1 = <RelayClientMessage>[];
      final firstMessage1 = Completer<void>();
      final sub1 = client.read(connection: connection).listen(
        (message) {
          msgs1.add(message);
          if (!firstMessage1.isCompleted) firstMessage1.complete();
        },
      );

      serverWs1.add("first");
      await firstMessage1.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(msgs1, hasLength(1));

      // Drop the connection from the server side, waiting for the client to
      // observe it before reconnecting.
      final dropped = client.connectionState.firstWhere((state) => state is RelayDisconnected);
      await serverWs1.close();
      await dropped.timeout(const Duration(seconds: 2));
      await sub1.cancel();

      // Reconnect — the server will accept a new WebSocket.
      final serverWs2Future = server.nextClient();
      await client.closeIfCurrent(connection: connection);
      connection = await client.connect();
      final serverWs2 = await serverWs2Future;

      // Verify the second connection works.
      final msgs2 = <RelayClientMessage>[];
      final firstMessage2 = Completer<void>();
      final sub2 = client.read(connection: connection).listen(
        (message) {
          msgs2.add(message);
          if (!firstMessage2.isCompleted) firstMessage2.complete();
        },
      );

      serverWs2.add("second");
      await firstMessage2.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(msgs2, hasLength(1));

      await sub2.cancel();
    });

    test("send works after reconnect", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      var connection = await client.connect();
      addTearDown(() => client.closeIfCurrent(connection: connection));

      final serverWs1 = await server.nextClient();

      // Capture data received by the server on each connection.
      final received1 = <dynamic>[];
      final firstFrame1 = Completer<void>();
      serverWs1.listen((data) {
        received1.add(data);
        if (!firstFrame1.isCompleted && data is! String) firstFrame1.complete();
      });

      expect(
        client.sendIfCurrent(
          connection: connection,
          connID: 1,
          payload: Uint8List.fromList("before".codeUnits),
        ),
        RelaySendOutcome.sent,
      );
      await firstFrame1.future.timeout(const Duration(seconds: 2));
      // Let any duplicate frame the client might have sent surface before the
      // exact one-frame assertion runs.
      await pumpEventQueue();
      expect(received1, hasLength(1));

      // Drop the connection, waiting for the client to observe it first.
      client.read(connection: connection).listen((_) {});
      final dropped = client.connectionState.firstWhere((state) => state is RelayDisconnected);
      await serverWs1.close();
      await dropped.timeout(const Duration(seconds: 2));

      // Reconnect.
      final serverWs2Future = server.nextClient();
      await client.closeIfCurrent(connection: connection);
      connection = await client.connect();
      final serverWs2 = await serverWs2Future;

      final received2 = <dynamic>[];
      final firstFrame2 = Completer<void>();
      serverWs2.listen((data) {
        received2.add(data);
        if (!firstFrame2.isCompleted && data is! String) firstFrame2.complete();
      });

      expect(
        client.sendIfCurrent(
          connection: connection,
          connID: 2,
          payload: Uint8List.fromList("after".codeUnits),
        ),
        RelaySendOutcome.sent,
      );
      await firstFrame2.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(received2, hasLength(1));
    });

    test("stale send and close cannot affect a successor connection", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);
      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final firstConnection = await client.connect();
      final firstSocket = await server.nextClient();
      final firstDone = Completer<void>();
      client.read(connection: firstConnection).listen((_) {}, onDone: firstDone.complete);
      await firstSocket.close();
      await firstDone.future.timeout(const Duration(seconds: 5));

      expect(
        client.sendIfCurrent(
          connection: firstConnection,
          connID: 1,
          payload: Uint8List.fromList(const [1]),
        ),
        RelaySendOutcome.stale,
      );

      final secondSocketFuture = server.nextClient();
      await client.closeIfCurrent(connection: firstConnection);
      final secondConnection = await client.connect();
      _closeAfterTest(client: client, connection: secondConnection);
      final secondSocket = await secondSocketFuture;
      final received = <dynamic>[];
      final firstFrame = Completer<void>();
      secondSocket.listen((data) {
        received.add(data);
        if (!firstFrame.isCompleted && data is! String) firstFrame.complete();
      });

      expect(
        client.sendIfCurrent(
          connection: firstConnection,
          connID: 1,
          payload: Uint8List.fromList(const [1]),
        ),
        RelaySendOutcome.stale,
      );
      expect(
        await client.closeIfCurrent(connection: firstConnection),
        RelayCloseOutcome.stale,
      );
      expect(
        client.sendIfCurrent(
          connection: secondConnection,
          connID: 2,
          payload: Uint8List.fromList(const [2]),
        ),
        RelaySendOutcome.sent,
      );
      await firstFrame.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(received, hasLength(1));
    });

    test("closeIfCurrent detaches synchronously before its handshake", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);
      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final firstConnection = await client.connect();
      await server.nextClient();

      final closeFuture = client.closeIfCurrent(connection: firstConnection);
      expect(
        client.sendIfCurrent(
          connection: firstConnection,
          connID: 1,
          payload: Uint8List.fromList(const [1]),
        ),
        RelaySendOutcome.stale,
      );
      final secondSocketFuture = server.nextClient();
      final secondConnection = await client.connect();
      _closeAfterTest(client: client, connection: secondConnection);
      await secondSocketFuture;

      expect(await closeFuture, RelayCloseOutcome.closed);
    });

    test("TestRelayServer.close rejects pending nextClient waiters", () async {
      final server = await TestRelayServer.start();

      // Request a client that will never arrive.
      final pending = server.nextClient();

      // Set up the matcher BEFORE close() so the error is captured.
      final expectation = expectLater(pending, throwsA(isA<StateError>()));

      // Close the server — the pending future should error, not hang.
      await server.close();
      await expectation;
    });

    test("connect times out against unresponsive server", () async {
      // Bind a TCP server that accepts connections but never completes
      // the WebSocket upgrade handshake.
      final rawServer = await ServerSocket.bind("127.0.0.1", 0);
      addTearDown(rawServer.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${rawServer.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
        connectTimeout: const Duration(milliseconds: 500),
      );

      await expectLater(client.connect(), throwsA(isA<TimeoutException>()));
    });
  });
}

class _ThrowingAccessTokenProvider() extends FakeAccessTokenProvider {
  @override
  String get accessToken => throw StateError("auth token unavailable");
}

/// Subscribes to [stream] before any connect and completes once [count]
/// events have been observed, returning the recorded events. Event-driven
/// replacement for fixed `Future.delayed` sleeps after connect.
Future<List<RelayConnectionState>> _recordStates({
  required Stream<RelayConnectionState> stream,
  required int count,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final states = <RelayConnectionState>[];
  if (count <= 0) return states;
  final reached = Completer<void>();
  late final StreamSubscription<RelayConnectionState> sub;
  sub = stream.listen((state) {
    states.add(state);
    if (!reached.isCompleted && states.length >= count) {
      reached.complete();
    }
  });
  try {
    await reached.future.timeout(timeout);
    // Keep observing through a microtask drain so any state emitted right
    // after the expected count (e.g. a duplicate) is still recorded before
    // callers run their exact-length assertions.
    await pumpEventQueue();
  } finally {
    await sub.cancel();
  }
  return states;
}

Future<Map<String, dynamic>> _firstTextFrame(WebSocket socket) async {
  final message = await socket.firstWhere((dynamic data) => data is String).timeout(const Duration(seconds: 5));
  return jsonDecodeMap(message as String);
}

void _closeAfterTest({
  required RelayClient client,
  required RelayConnection connection,
}) {
  addTearDown(() => client.closeIfCurrent(connection: connection));
}
