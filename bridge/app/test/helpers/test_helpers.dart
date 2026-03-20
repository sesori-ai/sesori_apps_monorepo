import "dart:async";
import "dart:collection";
import "dart:io";
import "dart:math";

import "package:sesori_bridge/src/bridge/relay_client.dart";

List<int> makeRoomKey() {
  final random = Random.secure();
  return List<int>.generate(32, (_) => random.nextInt(256));
}

Future<(HttpServer, Stream<List<int>>)> startTestRelayServer() async {
  final controller = StreamController<List<int>>.broadcast();
  final server = await HttpServer.bind("127.0.0.1", 0);

  server.listen((request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final ws = await WebSocketTransformer.upgrade(request);
    ws.listen((dynamic data) {
      if (data is List<int>) {
        controller.add(List<int>.from(data));
      }
    });
  });

  return (server, controller.stream);
}

Future<RelayClient> connectTestRelayClient(HttpServer server) async {
  final client = RelayClient("ws://127.0.0.1:${server.port}", "");
  await client.connect();
  return client;
}

/// A test relay server that exposes individual server-side [WebSocket]
/// connections so tests can send data to clients or close connections
/// to simulate network failures.
class TestRelayServer {
  final HttpServer _server;
  final Queue<WebSocket> _bufferedClients = Queue();
  final Queue<Completer<WebSocket>> _waiters = Queue();

  TestRelayServer._(this._server);

  static Future<TestRelayServer> start() async {
    final server = await HttpServer.bind("127.0.0.1", 0);
    final instance = TestRelayServer._(server);
    server.listen(instance._handleRequest);
    return instance;
  }

  int get port => _server.port;

  /// Returns the next client [WebSocket] that connects to this server.
  ///
  /// If a client already connected and is waiting, returns immediately.
  /// Otherwise blocks until a new client arrives (with a 5 s timeout).
  Future<WebSocket> nextClient() {
    if (_bufferedClients.isNotEmpty) {
      return Future.value(_bufferedClients.removeFirst());
    }
    final completer = Completer<WebSocket>();
    _waiters.add(completer);
    return completer.future.timeout(const Duration(seconds: 5));
  }

  Future<void> close() async {
    for (final completer in _waiters) {
      if (!completer.isCompleted) {
        completer.completeError(StateError("TestRelayServer is closing"));
      }
    }
    _waiters.clear();

    for (final ws in _bufferedClients) {
      await ws.close();
    }
    _bufferedClients.clear();

    await _server.close();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final ws = await WebSocketTransformer.upgrade(request);
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(ws);
    } else {
      _bufferedClients.add(ws);
    }
  }
}
