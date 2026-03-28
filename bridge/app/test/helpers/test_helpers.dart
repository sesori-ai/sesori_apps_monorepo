import "dart:async";
import "dart:collection";
import "dart:io";
import "dart:math";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/auth/access_token_provider.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_shared/sesori_shared.dart";

class FakeAccessTokenProvider implements AccessTokenProvider {
  final BehaviorSubject<String> _subject;

  FakeAccessTokenProvider([String token = "test-token"]) : _subject = BehaviorSubject.seeded(token);

  @override
  String get accessToken => _subject.value;

  @override
  ValueStream<String> get tokenStream => _subject.stream;
}

class FakeFailureReporter implements FailureReporter {
  @override
  void setGlobalKey({required String key, required Object value}) {}

  @override
  void log({required String message}) {}

  @override
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  }) => Future<void>.value();
}

/// A [FailureReporter] that captures recorded failure identifiers for assertions.
class CapturingFailureReporter extends FakeFailureReporter {
  final List<String> recordedIdentifiers = [];

  @override
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  }) async {
    recordedIdentifiers.add(uniqueIdentifier);
    await super.recordFailure(
      error: error,
      stackTrace: stackTrace,
      uniqueIdentifier: uniqueIdentifier,
      fatal: fatal,
      reason: reason,
      information: information,
    );
  }
}

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
  final client = RelayClient(
    relayURL: "ws://127.0.0.1:${server.port}",
    accessTokenProvider: FakeAccessTokenProvider(),
  );
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
