import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/testing/test_helpers.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockRelayCryptoService() extends Mock implements RelayCryptoService;

class _MockRoomKeyStorage() extends Mock implements RoomKeyStorage;

class _MockAuthTokenProvider() extends Mock implements AuthTokenProvider;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockLifecycleSource() extends Mock implements LifecycleSource;

class _MockFailureReporter() extends Mock implements FailureReporter;

class _MockRelayClient() extends Mock implements RelayClient;

class _RecordingRelayClientFactory(final _MockRelayClient Function() _produce) extends RelayClientFactory {
  int callCount = 0;
  String? lastAuthToken;

  @override
  RelayClient call({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
    required String? bridgeId,
  }) {
    callCount++;
    lastAuthToken = authToken;
    return _produce();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(const Duration(minutes: 1));
    registerFallbackValue(
      const RelayRequest(id: "fb", method: "GET", path: "/health", headers: {}, body: null),
    );
  });

  group("ConnectionService auth state handling", () {
    late _MockRelayCryptoService cryptoService;
    late _MockRoomKeyStorage roomKeyStorage;
    late _MockAuthTokenProvider authTokenProvider;
    late _MockAuthSession authSession;
    late _MockLifecycleSource lifecycleSource;
    late _MockFailureReporter failureReporter;
    late BehaviorSubject<LifecycleState> lifecycleController;
    late BehaviorSubject<AuthState> authStateController;

    setUp(() {
      cryptoService = _MockRelayCryptoService();
      roomKeyStorage = _MockRoomKeyStorage();
      authTokenProvider = _MockAuthTokenProvider();
      authSession = _MockAuthSession();
      lifecycleSource = _MockLifecycleSource();
      failureReporter = _MockFailureReporter();

      lifecycleController = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
      authStateController = BehaviorSubject<AuthState>.seeded(const AuthState.initial());

      when(() => lifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleController.stream);
      when(() => authSession.authStateStream).thenAnswer((_) => authStateController.stream);
      when(roomKeyStorage.clearRoomKey).thenAnswer((_) async {});
    });

    tearDown(() async {
      await lifecycleController.close();
      await authStateController.close();
    });

    test("AuthAuthenticated triggers connect with fresh token", () async {
      when(
        () => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenAnswer((_) async => "fresh-token-123");

      final relayClient = _MockRelayClient();
      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.isConnected).thenReturn(true);
      when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => relayClient.didResume).thenReturn(false);
      when(
        () => relayClient.sendRequest(
          request: any(named: "request"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) async => const RelayResponse(id: "r", status: 500, headers: {}, body: null),
      );
      when(relayClient.disconnect).thenAnswer((_) async {});

      final factory = _RecordingRelayClientFactory(() => relayClient);

      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        FakeTargetBridgeStorage(),
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      authStateController.add(
        const AuthState.authenticated(
          user: AuthUser(id: "u", provider: AuthProvider.github, providerUserId: "1", providerUsername: "u"),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(factory.callCount, equals(1));
      expect(factory.lastAuthToken, equals("fresh-token-123"));
      verify(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl"))).called(1);
    });

    test("AuthAuthenticated with null fresh token skips connect", () async {
      when(
        () => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenAnswer((_) async => null);

      final factory = _RecordingRelayClientFactory(_MockRelayClient.new);

      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        FakeTargetBridgeStorage(),
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      authStateController.add(
        const AuthState.authenticated(
          user: AuthUser(id: "u", provider: AuthProvider.github, providerUserId: "1", providerUsername: "u"),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(factory.callCount, equals(0));
    });

    test("AuthAuthenticated swallows token fetch errors without throwing", () async {
      when(
        () => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenThrow(StateError("token fetch failed"));

      final factory = _RecordingRelayClientFactory(_MockRelayClient.new);

      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        FakeTargetBridgeStorage(),
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      authStateController.add(
        const AuthState.authenticated(
          user: AuthUser(id: "u", provider: AuthProvider.github, providerUserId: "1", providerUsername: "u"),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(factory.callCount, equals(0));
      expect(service.currentStatus, isA<ConnectionDisconnected>());
    });

    test("AuthUnauthenticated disconnects and clears room key (regression)", () async {
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        FakeTargetBridgeStorage(),
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
      );
      addTearDown(service.dispose);

      service.emitStatusForTesting(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "t", bridgeId: null),
          health: HealthResponse(healthy: true, version: "1", filesystemAccessDegraded: false),
        ),
      );

      authStateController.add(const AuthState.unauthenticated());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.currentStatus, isA<ConnectionDisconnected>());
      verify(roomKeyStorage.clearRoomKey).called(1);
    });

    group("first connect failure", () {
      _MockRelayClient failingClient({required int? closeCode}) {
        final client = _MockRelayClient();
        when(client.connect).thenThrow(Exception("Failed host lookup"));
        when(() => client.lastCloseCode).thenReturn(closeCode);
        when(client.disconnect).thenAnswer((_) async {});
        return client;
      }

      _MockRelayClient workingClient() {
        final client = _MockRelayClient();
        when(client.connect).thenAnswer((_) async {});
        when(() => client.isConnected).thenReturn(true);
        when(() => client.connectionState).thenReturn(RelayClientConnectionState.connected);
        when(() => client.didResume).thenReturn(false);
        when(() => client.reportedBridgeId).thenReturn(null);
        when(() => client.lastCloseCode).thenReturn(null);
        when(
          () => client.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(
            id: "r",
            status: 200,
            headers: {},
            body: '{"healthy":true,"version":"1","filesystemAccessDegraded":false}',
          ),
        );
        when(() => client.subscribeSse(any())).thenAnswer((_) => const Stream.empty());
        when(() => client.bridgeStatus).thenAnswer((_) => const Stream.empty());
        when(() => client.bridgePresence).thenAnswer((_) => const Stream.empty());
        when(client.disconnect).thenAnswer((_) async {});
        return client;
      }

      ConnectionService serviceWith({required List<_MockRelayClient> clients}) {
        final remaining = clients.iterator;
        final service = ConnectionService(
          cryptoService,
          roomKeyStorage,
          FakeTargetBridgeStorage(),
          authTokenProvider,
          authSession,
          lifecycleSource,
          failureReporter,
          relayClientFactory: _RecordingRelayClientFactory(() {
            remaining.moveNext();
            return remaining.current;
          }),
        );
        addTearDown(service.dispose);
        return service;
      }

      setUp(() {
        when(() => authSession.currentState).thenReturn(const AuthState.initial());
        when(
          () => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
        ).thenAnswer((_) async => "token");
      });

      test("an unreachable relay is retried until it connects", () async {
        final service = serviceWith(clients: [failingClient(closeCode: null), workingClient()]);

        expect(await service.connectWithFreshAuthToken(), isFalse);
        expect(service.currentStatus, isA<ConnectionReconnecting>());

        await service.status.firstWhere((status) => status is ConnectionConnected).timeout(const Duration(seconds: 5));
      });

      test("a token that cannot refresh yet is retried until it connects", () async {
        final tokens = <String?>[null, "token"].iterator;
        when(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl"))).thenAnswer((_) async {
          tokens.moveNext();
          return tokens.current;
        });
        final service = serviceWith(clients: [workingClient()]);

        expect(await service.connectWithFreshAuthToken(), isFalse);
        expect(service.currentStatus, isA<ConnectionReconnecting>());

        await service.status.firstWhere((status) => status is ConnectionConnected).timeout(const Duration(seconds: 5));
      });

      test("a terminal close code is not retried", () async {
        final service = serviceWith(clients: [failingClient(closeCode: RelayCloseCodes.accountFull)]);

        expect(await service.connectWithFreshAuthToken(), isFalse);

        expect(service.currentStatus, isA<ConnectionDisconnected>());
      });

      test("a sign-out during the attempt is not retried", () async {
        when(() => authSession.currentState).thenReturn(const AuthState.unauthenticated());
        final service = serviceWith(clients: [failingClient(closeCode: null)]);

        expect(await service.connectWithFreshAuthToken(), isFalse);

        expect(service.currentStatus, isA<ConnectionDisconnected>());
      });

      test("a connect while the retry is pending opens no second socket", () async {
        final service = serviceWith(clients: [failingClient(closeCode: null), workingClient()]);
        await service.connectWithFreshAuthToken();

        expect(await service.connectWithFreshAuthToken(), isFalse);

        await service.status.firstWhere((status) => status is ConnectionConnected).timeout(const Duration(seconds: 5));
      });
    });
  });
}
