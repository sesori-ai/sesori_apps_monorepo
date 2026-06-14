import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayCryptoService extends Mock implements RelayCryptoService {}

class MockRoomKeyStorage extends Mock implements RoomKeyStorage {}

class MockAuthTokenProvider extends Mock implements AuthTokenProvider {}

class MockAuthSession extends Mock implements AuthSession {}

class MockLifecycleSource extends Mock implements LifecycleSource {}

class MockFailureReporter extends Mock implements FailureReporter {}

class MockRelayClient extends Mock implements RelayClient {}

class _TestRelayClientFactory extends RelayClientFactory {
  final RelayClient _client;
  _TestRelayClientFactory(this._client);

  @override
  RelayClient call({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
  }) => _client;
}

class _TestClockProvider extends ClockProvider {
  final DateTime Function() _now;
  _TestClockProvider(this._now);

  @override
  DateTime call() => _now();
}

void main() {
  setUpAll(() {
    registerFallbackValue(const Duration(minutes: 1));
    registerFallbackValue(
      const RelayRequest(id: "fallback", method: "GET", path: "/health", headers: {}, body: null),
    );
  });

  group("ConnectionService stale reconnect", () {
    late MockRelayCryptoService cryptoService;
    late MockRoomKeyStorage roomKeyStorage;
    late MockAuthTokenProvider authTokenProvider;
    late MockAuthSession authSession;
    late MockLifecycleSource lifecycleSource;
    late BehaviorSubject<LifecycleState> lifecycleController;
    late BehaviorSubject<AuthState> authStateController;
    late DateTime now;
    late ConnectionService service;

    const config = ServerConnectionConfig(
      relayHost: "relay.example.com",
      authToken: "token",
    );

    const health = HealthResponse(healthy: true, version: "0.1.200");

    Future<void> flush() => Future<void>.delayed(Duration.zero);

    setUp(() {
      cryptoService = MockRelayCryptoService();
      roomKeyStorage = MockRoomKeyStorage();
      authTokenProvider = MockAuthTokenProvider();
      authSession = MockAuthSession();
      lifecycleSource = MockLifecycleSource();
      lifecycleController = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
      authStateController = BehaviorSubject<AuthState>.seeded(const AuthState.initial());
      now = DateTime(2025, 1, 1, 12, 0, 0);

      when(() => lifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleController.stream);
      when(() => authSession.authStateStream).thenAnswer((_) => authStateController.stream);

      service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        MockFailureReporter(),
        clock: _TestClockProvider(() => now),
      );
    });

    tearDown(() async {
      service.dispose();
      await lifecycleController.close();
      await authStateController.close();
    });

    test("dataMayBeStale emits when app resumes after >= 5 minutes pause", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 5));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 1);
      await sub.cancel();
    });

    test("dataMayBeStale does NOT emit when app resumes after < staleThreshold pause", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      // 4 minutes is safely under the 4:30 stale threshold (90% of 5 min)
      now = now.add(const Duration(minutes: 4));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 0);
      await sub.cancel();
    });

    test("dataMayBeStale emits when connection was dropped AND pause >= 5 minutes", () async {
      service.emitStatusForTesting(const ConnectionStatus.connectionLost(config: config));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 6));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 1);
      await sub.cancel();
    });

    test("dataMayBeStale does NOT emit when app was never connected (disconnected status)", () async {
      service.emitStatusForTesting(const ConnectionStatus.disconnected());

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 6));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 0);
      await sub.cancel();
    });

    test("backgroundedAt is reset on each new background entry", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 2));
      lifecycleController.add(LifecycleState.resumed);
      await flush();
      expect(staleEmissions, 0);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 6));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 1);
      await sub.cancel();
    });

    test("dataMayBeStale does NOT emit on repeated resume without intervening background", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      var staleEmissions = 0;
      final sub = service.dataMayBeStale.listen((_) => staleEmissions++);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(minutes: 6));
      lifecycleController.add(LifecycleState.resumed);
      await flush();
      expect(staleEmissions, 1);

      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(staleEmissions, 1);
      await sub.cancel();
    });

    test("proactively reconnects when resuming past the relay-drop threshold while still connected", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      lifecycleController.add(LifecycleState.paused);
      await flush();
      // 30s exceeds the resume reconnect threshold: the relay has very likely
      // already dropped the backgrounded phone, so a "connected" status is stale.
      now = now.add(const Duration(seconds: 30));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(service.currentStatus, isA<ConnectionReconnecting>());
    });

    test("does NOT reconnect when resuming quickly while still connected", () async {
      service.emitStatusForTesting(const ConnectionStatus.connected(config: config, health: health));

      lifecycleController.add(LifecycleState.paused);
      await flush();
      // 5s is well within the threshold: the socket is presumed alive.
      now = now.add(const Duration(seconds: 5));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(service.currentStatus, isA<ConnectionConnected>());
    });

    test("does NOT proactively reconnect on resume while bridge offline", () async {
      // While the bridge is offline the E2E handshake cannot complete, so a
      // forced reconnect would fail into the blocking ConnectionLost state.
      // Bridge-offline recovery instead relies on its relay watcher / socket
      // drop, so resume must leave the status untouched.
      service.emitStatusForTesting(const ConnectionStatus.bridgeOffline(config: config, health: health));

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(seconds: 30));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      expect(service.currentStatus, isA<ConnectionBridgeOffline>());
    });

    test("detaches the stale relay client on resume so requests stop using the dead socket", () async {
      final sseController = StreamController<RelaySseEvent>.broadcast();
      addTearDown(sseController.close);

      final relayClient = MockRelayClient();
      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.isConnected).thenReturn(true);
      when(() => relayClient.sendRequest(any())).thenAnswer(
        (_) async => const RelayResponse(id: "h", status: 200, body: "{}", headers: {}),
      );
      when(() => relayClient.subscribeSse(any())).thenAnswer((_) => sseController.stream);
      when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(relayClient.disconnect).thenAnswer((_) async {});
      when(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")))
          .thenAnswer((_) async => "token");

      final staleService = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        MockFailureReporter(),
        clock: _TestClockProvider(() => now),
        relayClientFactory: _TestRelayClientFactory(relayClient),
      );
      addTearDown(staleService.dispose);

      await staleService.connect(config);
      expect(staleService.relayClient, isNotNull);

      lifecycleController.add(LifecycleState.paused);
      await flush();
      now = now.add(const Duration(seconds: 30));
      lifecycleController.add(LifecycleState.resumed);
      await flush();

      // Eager teardown nulls the client immediately (before the reconnect
      // backoff elapses), so RelayHttpApiClient won't route through the zombie.
      expect(staleService.relayClient, isNull);
    });
  });
}
