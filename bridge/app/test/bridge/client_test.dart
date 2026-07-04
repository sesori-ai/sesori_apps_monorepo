import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  group("RelayClient", () {
    test("send prefixes payload with big-endian connID", () async {
      final (server, messageStream) = await startTestRelayServer();
      addTearDown(server.close);

      final client = await connectTestRelayClient(server);
      addTearDown(client.close);

      const tests = [
        (connID: 0, hi: 0x00, lo: 0x00),
        (connID: 3, hi: 0x00, lo: 0x03),
        (connID: 256, hi: 0x01, lo: 0x00),
        (connID: 65535, hi: 0xFF, lo: 0xFF),
      ];

      final payload = "test-payload".codeUnits;

      for (final tt in tests) {
        client.send(tt.connID, payload);

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

    test("send throws when websocket is not connected", () {
      final client = RelayClient(
        relayURL: "ws://localhost:9999",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );

      expect(
        () => client.send(0, "hello".codeUnits),
        throwsA(isA<StateError>()),
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
      await client.connect();
      addTearDown(client.close);

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
      await client.connect();
      addTearDown(client.close);

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
      await client.connect();
      addTearDown(client.close);

      final serverWs = await server.nextClient();
      expect(client.closeCode, isNull);

      final streamDone = Completer<void>();
      client.read().listen((_) {}, onDone: streamDone.complete);
      await serverWs.close(RelayCloseCodes.bridgeRevoked);
      await streamDone.future.timeout(const Duration(seconds: 5));

      expect(client.closeCode, equals(RelayCloseCodes.bridgeRevoked));
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
      final states = <RelayConnectionState>[];
      client.connectionState.listen(states.add);

      await client.connect();
      addTearDown(client.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, hasLength(2));
      expect(states[0], isA<RelayConnecting>());
      expect(states[1], isA<RelayConnected>());
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
      await client.connect();
      addTearDown(client.close);

      final serverWs = await server.nextClient();
      // Drop detection requires the inbound stream to be consumed, exactly
      // like the orchestrator's relay loop does on a live connection.
      client.read().listen((_) {});
      final disconnected = client.connectionState.firstWhere((state) => state is RelayDisconnected);
      await serverWs.close(RelayCloseCodes.bridgeRevoked);

      final state = await disconnected.timeout(const Duration(seconds: 5)) as RelayDisconnected;
      expect(state.closeCode, equals(RelayCloseCodes.bridgeRevoked));
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
      await client.connect();
      await server.nextClient();

      await client.close();
      // Give the sink-done watcher time to fire if it (incorrectly) would.
      await Future<void>.delayed(const Duration(milliseconds: 200));

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
      final states = <RelayConnectionState>[];
      client.connectionState.listen(states.add);

      await expectLater(client.connect(), throwsA(isA<TimeoutException>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states[0], isA<RelayConnecting>());
      expect(states[1], isA<RelayDisconnected>());
      expect((states[1] as RelayDisconnected).closeCode, isNull);
    });

    test("reconnect after a remote drop emits connecting then connected again", () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final client = RelayClient(
        relayURL: "ws://127.0.0.1:${server.port}",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      final states = <RelayConnectionState>[];
      client.connectionState.listen(states.add);
      await client.connect();
      addTearDown(client.close);

      final serverWs1 = await server.nextClient();
      // Drop detection requires the inbound stream to be consumed, exactly
      // like the orchestrator's relay loop does on a live connection.
      client.read().listen((_) {});
      final disconnected = client.connectionState.firstWhere((state) => state is RelayDisconnected);
      await serverWs1.close();
      await disconnected.timeout(const Duration(seconds: 5));

      final serverWs2Future = server.nextClient();
      await client.reconnect();
      await serverWs2Future;
      await Future<void>.delayed(const Duration(milliseconds: 50));

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
      await client.connect();
      addTearDown(client.close);

      final serverWs = await server.nextClient();

      final messages = <RelayClientMessage>[];
      final done = Completer<void>();

      client.read().listen(
        messages.add,
        onDone: done.complete,
        onError: done.completeError,
      );

      // Send a message and verify receipt.
      serverWs.add("hello");
      await Future<void>.delayed(const Duration(milliseconds: 100));
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
      await client.connect();
      addTearDown(client.close);

      final serverWs = await server.nextClient();

      var messageCount = 0;
      final loopExited = Completer<void>();

      unawaited(
        (() async {
          await for (final _ in client.read()) {
            messageCount++;
          }
          loopExited.complete();
        })(),
      );

      // Deliver a message so we know the loop is running.
      serverWs.add("ping");
      await Future<void>.delayed(const Duration(milliseconds: 100));
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
      await client.connect();
      addTearDown(client.close);

      final serverWs1 = await server.nextClient();

      // Verify the first connection works.
      final msgs1 = <RelayClientMessage>[];
      final sub1 = client.read().listen(msgs1.add);

      serverWs1.add("first");
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(msgs1, hasLength(1));
      await sub1.cancel();

      // Drop the connection from the server side.
      await serverWs1.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Reconnect — the server will accept a new WebSocket.
      final serverWs2Future = server.nextClient();
      await client.reconnect();
      final serverWs2 = await serverWs2Future;

      // Verify the second connection works.
      final msgs2 = <RelayClientMessage>[];
      final sub2 = client.read().listen(msgs2.add);

      serverWs2.add("second");
      await Future<void>.delayed(const Duration(milliseconds: 100));
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
      await client.connect();
      addTearDown(client.close);

      final serverWs1 = await server.nextClient();

      // Capture data received by the server on each connection.
      final received1 = <dynamic>[];
      serverWs1.listen(received1.add);

      client.send(1, "before".codeUnits);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(received1, hasLength(1));

      // Drop connection.
      await serverWs1.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Reconnect.
      final serverWs2Future = server.nextClient();
      await client.reconnect();
      final serverWs2 = await serverWs2Future;

      final received2 = <dynamic>[];
      serverWs2.listen(received2.add);

      client.send(2, "after".codeUnits);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(received2, hasLength(1));
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

Future<Map<String, dynamic>> _firstTextFrame(WebSocket socket) async {
  final message = await socket.firstWhere((dynamic data) => data is String).timeout(const Duration(seconds: 5));
  return jsonDecodeMap(message as String);
}
