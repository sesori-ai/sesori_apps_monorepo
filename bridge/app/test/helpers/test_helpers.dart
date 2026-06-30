import "dart:async";
import "dart:collection";
import "dart:io";
import "dart:math";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/auth/access_token_provider.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/auth/bridge_id_storage.dart";
import "package:sesori_bridge/src/auth/bridge_registration_repository.dart";
import "package:sesori_bridge/src/auth/bridge_registration_service.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
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

class FakeBridgeIdProvider implements BridgeIdProvider {
  String? id;

  FakeBridgeIdProvider([this.id]);

  @override
  String? get bridgeId => id;
}

class FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "test-token";
}

/// In-memory [BridgeIdStorage] substitute for [BridgeRegistrationService] tests.
class FakeBridgeIdStorage implements BridgeIdStorage {
  String? bridgeId;

  /// When non-null, [clear] throws this error instead of clearing.
  Object? clearError;

  /// When non-null, [write] throws this error instead of persisting.
  Object? writeError;

  FakeBridgeIdStorage({this.bridgeId});

  @override
  Future<String?> read() async => bridgeId;

  @override
  Future<void> write({required String bridgeId}) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    this.bridgeId = bridgeId;
  }

  @override
  Future<void> clear() async {
    final error = clearError;
    if (error != null) {
      throw error;
    }
    bridgeId = null;
  }
}

/// A [BridgeRegistrationRepository] fake that records calls and returns
/// configurable results without touching the network.
class FakeBridgeRegistrationRepository implements BridgeRegistrationRepository {
  /// The bridge ids that [register] was called with, in order.
  final List<String?> registeredBridgeIds = [];

  /// The bridge ids that [unregister] was called with, in order.
  final List<String> unregisteredBridgeIds = [];

  /// When non-null, [register] throws this error instead of succeeding.
  Object? registerError;

  /// The id returned from successful [register] calls.
  String nextBridgeId = "br_test1234";

  @override
  Future<BridgeSummary> register({
    required String name,
    required String platform,
    required String? bridgeId,
    required String accessToken,
  }) async {
    registeredBridgeIds.add(bridgeId);
    if (registerError != null) {
      throw registerError!;
    }
    return BridgeSummary(
      id: nextBridgeId,
      name: name,
      platform: platform,
      addedAt: DateTime.utc(2026, 6, 1),
      lastSeenAt: null,
    );
  }

  @override
  Future<void> unregister({required String bridgeId, required String accessToken}) async {
    unregisteredBridgeIds.add(bridgeId);
  }
}

/// Builds a [BridgeRegistrationService] backed by in-memory fakes, suitable
/// for orchestrator and runtime tests.
BridgeRegistrationService createFakeBridgeRegistrationService({
  BridgeRegistrationRepository? repository,
  BridgeIdStorage? bridgeIdStorage,
}) {
  return BridgeRegistrationService(
    repository: repository ?? FakeBridgeRegistrationRepository(),
    tokenRefresher: FakeTokenRefresher(),
    bridgeIdStorage: bridgeIdStorage ?? FakeBridgeIdStorage(),
    hostName: "test-host",
    platform: "macos",
  );
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
    bridgeIdProvider: FakeBridgeIdProvider(),
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
  int _acceptedClientCount = 0;

  TestRelayServer._(this._server);

  static Future<TestRelayServer> start() async {
    final server = await HttpServer.bind("127.0.0.1", 0);
    final instance = TestRelayServer._(server);
    server.listen(instance._handleRequest);
    return instance;
  }

  int get port => _server.port;

  /// Number of WebSocket clients the server has accepted, counted at accept time
  /// (not when a test consumes one via [nextClient]). A "no reconnect" assertion
  /// must read this so a spurious reconnect that sits buffered is still observed.
  int get acceptedClientCount => _acceptedClientCount;

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
    _acceptedClientCount += 1;
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(ws);
    } else {
      _bufferedClients.add(ws);
    }
  }
}
