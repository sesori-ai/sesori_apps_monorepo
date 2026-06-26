import "dart:async";
import "dart:collection";
import "dart:io";

import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:test/test.dart";

void main() {
  group("ControlChannelClient", () {
    test("connects and presents the secret as an Authorization bearer header", () async {
      final server = await _FakeControlServer.start();
      addTearDown(server.close);

      final client = ControlChannelClient(
        url: Uri.parse("ws://127.0.0.1:${server.port}"),
        secret: "s3cr3t-token",
      );
      await client.connect();
      addTearDown(client.dispose);

      final connection = await server.nextConnection();
      expect(connection.authorizationHeader, equals("Bearer s3cr3t-token"));
    });

    test("surfaces inbound text frames on the inbound stream", () async {
      final server = await _FakeControlServer.start();
      addTearDown(server.close);

      final client = ControlChannelClient(
        url: Uri.parse("ws://127.0.0.1:${server.port}"),
        secret: "x",
      );
      await client.connect();
      addTearDown(client.dispose);

      final connection = await server.nextConnection();
      final received = client.inbound.first;
      connection.socket.add("hello-from-gui");

      expect(await received.timeout(const Duration(seconds: 5)), equals("hello-from-gui"));
    });

    test("send delivers a frame to the server", () async {
      final server = await _FakeControlServer.start();
      addTearDown(server.close);

      final client = ControlChannelClient(
        url: Uri.parse("ws://127.0.0.1:${server.port}"),
        secret: "x",
      );
      await client.connect();
      addTearDown(client.dispose);

      final connection = await server.nextConnection();
      final serverReceived = connection.socket.cast<String>().first;
      client.send("ping");

      expect(await serverReceived.timeout(const Duration(seconds: 5)), equals("ping"));
    });

    test("auto-reconnects after the server drops the connection", () async {
      final server = await _FakeControlServer.start();
      addTearDown(server.close);

      final client = ControlChannelClient(
        url: Uri.parse("ws://127.0.0.1:${server.port}"),
        secret: "x",
        initialReconnectDelay: const Duration(milliseconds: 20),
      );
      final states = <ControlChannelConnectionState>[];
      client.connectionState.listen(states.add);
      await client.connect();
      addTearDown(client.dispose);

      final first = await server.nextConnection();
      await first.socket.close();

      // The client must dial a fresh connection (still presenting the secret).
      final second = await server.nextConnection();
      expect(second.authorizationHeader, equals("Bearer x"));
      await _waitFor(() => states.contains(ControlChannelConnectionState.disconnected));
    });

    test("connect throws when the server never completes the handshake", () async {
      // Bind but never accept/upgrade: the WebSocket handshake never resolves.
      final rawServer = await ServerSocket.bind("127.0.0.1", 0);
      addTearDown(rawServer.close);

      final client = ControlChannelClient(
        url: Uri.parse("ws://127.0.0.1:${rawServer.port}"),
        secret: "x",
        connectTimeout: const Duration(milliseconds: 300),
      );

      await expectLater(client.connect(), throwsA(isA<TimeoutException>()));
    });

    test("dispose closes the inbound and connection-state streams", () async {
      final server = await _FakeControlServer.start();
      addTearDown(server.close);

      final client = ControlChannelClient(
        url: Uri.parse("ws://127.0.0.1:${server.port}"),
        secret: "x",
      );
      await client.connect();
      await server.nextConnection();

      await client.dispose();

      expect(client.inbound, emitsDone);
      expect(client.connectionState, emitsDone);
    });
  });
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail("Timed out waiting for condition");
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _FakeControlConnection {
  final WebSocket socket;
  final String? authorizationHeader;

  const _FakeControlConnection({required this.socket, required this.authorizationHeader});
}

/// A loopback control server that records the upgrade `Authorization` header
/// and exposes each accepted connection so a test can drive the GUI side.
class _FakeControlServer {
  final HttpServer _server;
  final Queue<_FakeControlConnection> _buffered = Queue<_FakeControlConnection>();
  final Queue<Completer<_FakeControlConnection>> _waiters = Queue<Completer<_FakeControlConnection>>();

  _FakeControlServer._(this._server);

  static Future<_FakeControlServer> start() async {
    final server = await HttpServer.bind("127.0.0.1", 0);
    final instance = _FakeControlServer._(server);
    server.listen(instance._handleRequest);
    return instance;
  }

  int get port => _server.port;

  Future<_FakeControlConnection> nextConnection() {
    if (_buffered.isNotEmpty) {
      return Future.value(_buffered.removeFirst());
    }
    final completer = Completer<_FakeControlConnection>();
    _waiters.add(completer);
    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<void> close() async {
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.completeError(StateError("server closing"));
      }
    }
    _waiters.clear();
    for (final connection in _buffered) {
      await connection.socket.close();
    }
    _buffered.clear();
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final authorization = request.headers.value("authorization");
    final socket = await WebSocketTransformer.upgrade(request);
    final connection = _FakeControlConnection(socket: socket, authorizationHeader: authorization);
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(connection);
    } else {
      _buffered.add(connection);
    }
  }
}
