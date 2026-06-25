import "dart:async";
import "dart:convert";

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
  final RelayClient Function({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
  })
  _factory;

  int callCount = 0;

  _TestRelayClientFactory(this._factory);

  @override
  RelayClient call({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
  }) {
    callCount++;
    return _factory(
      relayHost: relayHost,
      cryptoService: cryptoService,
      roomKeyStorage: roomKeyStorage,
      authToken: authToken,
    );
  }
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
      const RelayRequest(
        id: "fallback-request-id",
        method: "GET",
        path: "/health",
        headers: {},
        body: null,
      ),
    );
  });

  group("ConnectionService reconnect guards", () {
    late MockRelayCryptoService cryptoService;
    late MockRoomKeyStorage roomKeyStorage;
    late MockAuthTokenProvider authTokenProvider;
    late MockAuthSession authSession;
    late MockLifecycleSource lifecycleSource;
    late MockFailureReporter failureReporter;
    late BehaviorSubject<LifecycleState> lifecycleController;
    late BehaviorSubject<AuthState> authStateController;

    const config = ServerConnectionConfig(
      relayHost: "relay.example.com",
      authToken: "token",
    );

    const health = HealthResponse(healthy: true, version: "0.1.200");

    setUp(() {
      cryptoService = MockRelayCryptoService();
      roomKeyStorage = MockRoomKeyStorage();
      authTokenProvider = MockAuthTokenProvider();
      authSession = MockAuthSession();
      lifecycleSource = MockLifecycleSource();
      failureReporter = MockFailureReporter();

      lifecycleController = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
      authStateController = BehaviorSubject<AuthState>.seeded(const AuthState.initial());

      when(() => lifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleController.stream);
      when(() => authSession.authStateStream).thenAnswer((_) => authStateController.stream);
      when(
        () => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenAnswer((_) async => "fresh-token");
      when(roomKeyStorage.clearRoomKey).thenAnswer((_) async {});
    });

    tearDown(() async {
      await lifecycleController.close();
      await authStateController.close();
    });

    test("disconnect cancels reconnect timer before token refresh", () async {
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
      );
      addTearDown(service.dispose);

      service.emitStatusForTesting(const ConnectionStatus.connectionLost(config: config));
      service.reconnect();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      service.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyNever(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")));
      expect(service.currentStatus, isA<ConnectionDisconnected>());
    });

    test("backgrounding during reconnect delay prevents refresh and reconnect", () async {
      final tokenCompleter = Completer<String?>();
      when(
        () => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenAnswer((_) => tokenCompleter.future);

      final relayClient = MockRelayClient();
      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => relayClient,
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      service.emitStatusForTesting(const ConnectionStatus.connectionLost(config: config));
      service.reconnect();

      await Future<void>.delayed(const Duration(milliseconds: 1400));
      verify(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl"))).called(1);

      lifecycleController.add(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      tokenCompleter.complete("fresh-token");

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.currentStatus, const ConnectionStatus.connectionLost(config: config));
      expect(factory.callCount, 0);
    });

    test("SSE setup failure disconnects relay and returns error response", () async {
      final relayClient = MockRelayClient();

      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.didResume).thenReturn(false);
      when(() => relayClient.sendRequest(any())).thenAnswer(
        (_) async => RelayResponse(
          id: "1",
          status: 200,
          body: jsonEncode(health.toJson()),
          headers: const {},
        ),
      );
      when(() => relayClient.subscribeSse(any())).thenThrow(StateError("SSE subscribe failed"));
      when(() => relayClient.isConnected).thenReturn(true);
      when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(relayClient.disconnect).thenAnswer((_) async {});
      when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());

      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => relayClient,
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      final result = await service.connect(config);

      expect(result, isA<ErrorResponse<HealthResponse>>());
      expect(service.relayClient, isNull);
      expect(service.currentStatus, isNot(isA<ConnectionConnected>()));
      verify(relayClient.disconnect).called(greaterThanOrEqualTo(1));
    });

    test("resumed connect skips the GET /health round-trip", () async {
      final sseController = StreamController<RelaySseEvent>.broadcast();
      addTearDown(sseController.close);

      final relayClient = MockRelayClient();
      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.isConnected).thenReturn(true);
      when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => relayClient.didResume).thenReturn(true);
      when(() => relayClient.subscribeSse(any())).thenAnswer((_) => sseController.stream);
      when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(relayClient.disconnect).thenAnswer((_) async {});

      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => relayClient,
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      await service.connect(config);

      verifyNever(() => relayClient.sendRequest(any()));
      expect(service.currentStatus, isA<ConnectionConnected>());
    });

    test("fresh-DH connect still sends GET /health", () async {
      final sseController = StreamController<RelaySseEvent>.broadcast();
      addTearDown(sseController.close);

      final relayClient = MockRelayClient();
      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.isConnected).thenReturn(true);
      when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => relayClient.didResume).thenReturn(false);
      when(() => relayClient.sendRequest(any())).thenAnswer(
        (_) async => const RelayResponse(id: "h", status: 200, body: "{}", headers: {}),
      );
      when(() => relayClient.subscribeSse(any())).thenAnswer((_) => sseController.stream);
      when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(relayClient.disconnect).thenAnswer((_) async {});

      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => relayClient,
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      await service.connect(config);

      verify(() => relayClient.sendRequest(any())).called(1);
      expect(service.currentStatus, isA<ConnectionConnected>());
    });

    test(
      "foreground resume attempts the first reconnect immediately, without the backoff delay",
      () async {
        // Keep the SSE stream open so the reconnected client stays Connected — an
        // already-closed stream would immediately re-trigger a drop.
        final sseController = StreamController<RelaySseEvent>.broadcast();
        addTearDown(sseController.close);

        final relayClient = MockRelayClient();
        when(relayClient.connect).thenAnswer((_) async {});
        when(() => relayClient.didResume).thenReturn(false);
        when(() => relayClient.isConnected).thenReturn(true);
        when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
        when(() => relayClient.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(id: "h", status: 200, body: "{}", headers: {}),
        );
        when(() => relayClient.subscribeSse(any())).thenAnswer((_) => sseController.stream);
        when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
        when(relayClient.disconnect).thenAnswer((_) async {});

        var now = DateTime(2025, 1, 1, 12, 0, 0);
        final factory = _TestRelayClientFactory(
          ({
            required String relayHost,
            required RelayCryptoService cryptoService,
            required RoomKeyStorage roomKeyStorage,
            required String? authToken,
          }) => relayClient,
        );
        final service = ConnectionService(
          cryptoService,
          roomKeyStorage,
          authTokenProvider,
          authSession,
          lifecycleSource,
          failureReporter,
          clock: _TestClockProvider(() => now),
          relayClientFactory: factory,
        );
        addTearDown(service.dispose);

        // Establish the initial connection (1st factory call).
        await service.connect(config);
        expect(factory.callCount, 1);
        expect(service.currentStatus, isA<ConnectionConnected>());

        // Background, then resume past the relay-drop threshold so the still-
        // "connected" socket is treated as stale and a reconnect is triggered.
        lifecycleController.add(LifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        now = now.add(const Duration(seconds: 30));
        lifecycleController.add(LifecycleState.resumed);

        // Far below the 1s backoff: if the first attempt were still gated on the
        // backoff timer the factory would not have been called again yet.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(factory.callCount, 2);
        expect(service.currentStatus, isA<ConnectionConnected>());
      },
    );

    test("a non-resume reconnect still waits the backoff before its first attempt", () async {
      final sseController = StreamController<RelaySseEvent>.broadcast();
      addTearDown(sseController.close);

      final relayClient = MockRelayClient();
      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.didResume).thenReturn(false);
      when(() => relayClient.isConnected).thenReturn(true);
      when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => relayClient.sendRequest(any())).thenAnswer(
        (_) async => const RelayResponse(id: "h", status: 200, body: "{}", headers: {}),
      );
      when(() => relayClient.subscribeSse(any())).thenAnswer((_) => sseController.stream);
      when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(relayClient.disconnect).thenAnswer((_) async {});

      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => relayClient,
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      // Manual reconnect is NOT the resume path, so it keeps the exponential
      // backoff (seeded at 1s): no attempt fires on the immediate tick.
      service.emitStatusForTesting(const ConnectionStatus.connectionLost(config: config));
      service.reconnect();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(factory.callCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 1400));
      expect(factory.callCount, 1);
    });

    test("a superseded reconnect attempt aborts after its async gap and does not open a second socket", () async {
      final sseController = StreamController<RelaySseEvent>.broadcast();
      addTearDown(sseController.close);

      final relayClient = MockRelayClient();
      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.didResume).thenReturn(false);
      when(() => relayClient.isConnected).thenReturn(true);
      when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => relayClient.sendRequest(any())).thenAnswer(
        (_) async => const RelayResponse(id: "h", status: 200, body: "{}", headers: {}),
      );
      when(() => relayClient.subscribeSse(any())).thenAnswer((_) => sseController.stream);
      when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(relayClient.disconnect).thenAnswer((_) async {});

      // Attempt 1's token refresh is held pending; Attempt 2's resolves
      // immediately, so Attempt 2 supersedes Attempt 1 while it is still parked.
      final firstToken = Completer<String?>();
      var tokenCalls = 0;
      when(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl"))).thenAnswer((_) {
        tokenCalls++;
        return tokenCalls == 1 ? firstToken.future : Future<String?>.value("token");
      });

      var now = DateTime(2025, 1, 1, 12, 0, 0);
      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => relayClient,
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        clock: _TestClockProvider(() => now),
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      await service.connect(config);
      expect(factory.callCount, 1);

      // Attempt 1: resume past the threshold → immediate reconnect, parks at token.
      lifecycleController.add(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 30));
      lifecycleController.add(LifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(factory.callCount, 1);

      // Attempt 2: background + resume again → supersedes Attempt 1 and connects.
      lifecycleController.add(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 30));
      lifecycleController.add(LifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(factory.callCount, 2);
      expect(service.currentStatus, isA<ConnectionConnected>());

      // Releasing Attempt 1's token must NOT open a third socket: it detects it
      // was superseded and bails after the await.
      firstToken.complete("token-stale");
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(factory.callCount, 2);
      expect(service.currentStatus, isA<ConnectionConnected>());
    });

    test("a superseded in-flight handshake is disconnected before the next reconnect opens", () async {
      final sseController = StreamController<RelaySseEvent>.broadcast();
      addTearDown(sseController.close);

      final initialClient = MockRelayClient();
      final firstReconnectClient = MockRelayClient();
      final secondReconnectClient = MockRelayClient();
      final firstConnect = Completer<void>();
      final clients = <MockRelayClient>[
        initialClient,
        firstReconnectClient,
        secondReconnectClient,
      ];

      for (final client in clients) {
        when(() => client.didResume).thenReturn(false);
        when(() => client.isConnected).thenReturn(true);
        when(() => client.connectionState).thenReturn(RelayClientConnectionState.connected);
        when(() => client.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(id: "h", status: 200, body: "{}", headers: {}),
        );
        when(() => client.subscribeSse(any())).thenAnswer((_) => sseController.stream);
        when(() => client.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
        when(client.disconnect).thenAnswer((_) async {});
      }
      when(initialClient.connect).thenAnswer((_) async {});
      when(firstReconnectClient.connect).thenAnswer((_) => firstConnect.future);
      when(secondReconnectClient.connect).thenAnswer((_) async {});

      var nextClient = 0;
      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => clients[nextClient++],
      );
      var now = DateTime(2025, 1, 1, 12, 0, 0);
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        clock: _TestClockProvider(() => now),
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      await service.connect(config);
      expect(service.relayClient, same(initialClient));

      lifecycleController.add(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 30));
      lifecycleController.add(LifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(factory.callCount, 2);
      expect(service.relayClient, isNull);

      lifecycleController.add(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 30));
      lifecycleController.add(LifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(firstReconnectClient.disconnect).called(greaterThanOrEqualTo(1));
      expect(factory.callCount, 3);
      expect(service.relayClient, same(secondReconnectClient));
      expect(service.currentStatus, isA<ConnectionConnected>());

      firstConnect.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verifyNever(() => firstReconnectClient.sendRequest(any()));
      expect(service.relayClient, same(secondReconnectClient));
      expect(service.currentStatus, isA<ConnectionConnected>());
    });

    test("backgrounding during an immediate reconnect handshake aborts without publishing connected", () async {
      final sseController = StreamController<RelaySseEvent>.broadcast();
      addTearDown(sseController.close);

      final initialClient = MockRelayClient();
      final reconnectClient = MockRelayClient();
      final reconnectConnect = Completer<void>();
      final clients = <MockRelayClient>[initialClient, reconnectClient];

      for (final client in clients) {
        when(() => client.didResume).thenReturn(false);
        when(() => client.isConnected).thenReturn(true);
        when(() => client.connectionState).thenReturn(RelayClientConnectionState.connected);
        when(() => client.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(id: "h", status: 200, body: "{}", headers: {}),
        );
        when(() => client.subscribeSse(any())).thenAnswer((_) => sseController.stream);
        when(() => client.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
        when(client.disconnect).thenAnswer((_) async {});
      }
      when(initialClient.connect).thenAnswer((_) async {});
      when(reconnectClient.connect).thenAnswer((_) => reconnectConnect.future);

      var nextClient = 0;
      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => clients[nextClient++],
      );
      var now = DateTime(2025, 1, 1, 12, 0, 0);
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        clock: _TestClockProvider(() => now),
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      await service.connect(config);
      expect(service.currentStatus, isA<ConnectionConnected>());

      lifecycleController.add(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 30));
      lifecycleController.add(LifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(factory.callCount, 2);

      lifecycleController.add(LifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      reconnectConnect.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.currentStatus, const ConnectionStatus.connectionLost(config: config));
      expect(service.relayClient, isNull);
      verify(reconnectClient.disconnect).called(greaterThanOrEqualTo(1));
      verifyNever(() => reconnectClient.sendRequest(any()));
    });

    test("connect with bridge absent parks in ConnectionBridgeOffline without health probe or SSE", () async {
      final relayClient = MockRelayClient();
      when(relayClient.connect).thenAnswer((_) async {});
      // Bridge absent: connect() returns with the transport state connected but
      // no session encryptor, so isConnected stays false.
      when(() => relayClient.isConnected).thenReturn(false);
      when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(() => relayClient.onSocketClosed).thenAnswer((_) => const Stream<void>.empty());
      when(relayClient.disconnect).thenAnswer((_) async {});

      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => relayClient,
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      final result = await service.connect(config);

      expect(result, isA<SuccessResponse<HealthResponse>>());
      expect(service.currentStatus, isA<ConnectionBridgeOffline>());
      expect(service.relayClient, same(relayClient));
      // No E2E session yet, so neither the health probe nor SSE should run.
      verifyNever(() => relayClient.sendRequest(any()));
      verifyNever(() => relayClient.subscribeSse(any()));
    });

    test("bridge coming online while parked drives a reconnect to ConnectionConnected", () async {
      final bridgeStatusController = StreamController<BridgeStatus>.broadcast();
      addTearDown(bridgeStatusController.close);

      final parkedClient = MockRelayClient();
      when(parkedClient.connect).thenAnswer((_) async {});
      when(() => parkedClient.isConnected).thenReturn(false);
      when(() => parkedClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => parkedClient.bridgeStatus).thenAnswer((_) => bridgeStatusController.stream);
      when(() => parkedClient.onSocketClosed).thenAnswer((_) => const Stream<void>.empty());
      when(parkedClient.disconnect).thenAnswer((_) async {});

      final sseController = StreamController<RelaySseEvent>.broadcast();
      addTearDown(sseController.close);
      final connectedClient = MockRelayClient();
      when(connectedClient.connect).thenAnswer((_) async {});
      when(() => connectedClient.isConnected).thenReturn(true);
      when(() => connectedClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => connectedClient.didResume).thenReturn(false);
      when(() => connectedClient.sendRequest(any())).thenAnswer(
        (_) async => RelayResponse(id: "h", status: 200, body: jsonEncode(health.toJson()), headers: const {}),
      );
      when(() => connectedClient.subscribeSse(any())).thenAnswer((_) => sseController.stream);
      when(() => connectedClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(() => connectedClient.onSocketClosed).thenAnswer((_) => const Stream<void>.empty());
      when(connectedClient.disconnect).thenAnswer((_) async {});

      final clients = <MockRelayClient>[parkedClient, connectedClient];
      var nextClient = 0;
      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => clients[nextClient++],
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      await service.connect(config);
      expect(service.currentStatus, isA<ConnectionBridgeOffline>());

      // The relay pushes bridge_connected over the still-open socket.
      bridgeStatusController.add(BridgeStatus.online);
      // The online handler runs _reconnectRelayWithRefresh(immediate: true), which
      // refreshes the token and reconnects with a fresh key exchange.
      await Future<void>.delayed(const Duration(milliseconds: 1400));

      expect(factory.callCount, 2);
      expect(service.relayClient, same(connectedClient));
      expect(service.currentStatus, isA<ConnectionConnected>());
    });

    test("socket closing while parked is recovered like an SSE drop", () async {
      final socketClosedController = StreamController<void>.broadcast();
      addTearDown(socketClosedController.close);

      final parkedClient = MockRelayClient();
      when(parkedClient.connect).thenAnswer((_) async {});
      when(() => parkedClient.isConnected).thenReturn(false);
      when(() => parkedClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => parkedClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(() => parkedClient.onSocketClosed).thenAnswer((_) => socketClosedController.stream);
      when(() => parkedClient.lastCloseCode).thenReturn(null);
      when(parkedClient.disconnect).thenAnswer((_) async {});

      final reparkedClient = MockRelayClient();
      when(reparkedClient.connect).thenAnswer((_) async {});
      when(() => reparkedClient.isConnected).thenReturn(false);
      when(() => reparkedClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => reparkedClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(() => reparkedClient.onSocketClosed).thenAnswer((_) => const Stream<void>.empty());
      when(reparkedClient.disconnect).thenAnswer((_) async {});

      final clients = <MockRelayClient>[parkedClient, reparkedClient];
      var nextClient = 0;
      final factory = _TestRelayClientFactory(
        ({
          required String relayHost,
          required RelayCryptoService cryptoService,
          required RoomKeyStorage roomKeyStorage,
          required String? authToken,
        }) => clients[nextClient++],
      );
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      await service.connect(config);
      expect(service.currentStatus, isA<ConnectionBridgeOffline>());

      // No SSE stream exists while parked, so the socket-closed signal is what
      // surfaces the drop. It should reconnect and (bridge still absent) re-park.
      socketClosedController.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 1400));

      expect(factory.callCount, 2);
      expect(service.relayClient, same(reparkedClient));
      expect(service.currentStatus, isA<ConnectionBridgeOffline>());
    });
  });
}
