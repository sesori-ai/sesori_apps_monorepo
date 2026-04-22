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

    const health = HealthResponse(healthy: true, version: "0.1.200", serverManaged: false, serverState: null);

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

      lifecycleController.add(LifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);
      tokenCompleter.complete("fresh-token");

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.currentStatus, const ConnectionStatus.connectionLost(config: config));
      expect(factory.callCount, 0);
    });

    test("SSE setup failure disconnects relay and returns error response", () async {
      final relayClient = MockRelayClient();

      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.sendRequest(any())).thenAnswer(
        (_) async => RelayResponse(
          id: "1",
          status: 200,
          body: jsonEncode(health.toJson()),
          headers: const {},
        ),
      );
      when(() => relayClient.subscribeSse(any())).thenThrow(StateError("SSE subscribe failed"));
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
  });
}
