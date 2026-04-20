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

class _MockRelayCryptoService extends Mock implements RelayCryptoService {}

class _MockRoomKeyStorage extends Mock implements RoomKeyStorage {}

class _MockAuthTokenProvider extends Mock implements AuthTokenProvider {}

class _MockAuthSession extends Mock implements AuthSession {}

class _MockLifecycleSource extends Mock implements LifecycleSource {}

class _MockFailureReporter extends Mock implements FailureReporter {}

class _MockRelayClient extends Mock implements RelayClient {}

class _RecordingRelayClientFactory extends RelayClientFactory {
  final _MockRelayClient Function() _produce;
  int callCount = 0;
  String? lastAuthToken;

  _RecordingRelayClientFactory(this._produce);

  @override
  RelayClient call({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
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
      when(() => relayClient.sendRequest(any())).thenAnswer(
        (_) async => const RelayResponse(id: "r", status: 500, headers: {}, body: null),
      );
      when(relayClient.disconnect).thenAnswer((_) async {});

      final factory = _RecordingRelayClientFactory(() => relayClient);

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

      authStateController.add(
        const AuthState.authenticated(user: AuthUser(id: "u", provider: "github", providerUserId: "1", providerUsername: "u")),
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
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      authStateController.add(
        const AuthState.authenticated(user: AuthUser(id: "u", provider: "github", providerUserId: "1", providerUsername: "u")),
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
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: factory,
      );
      addTearDown(service.dispose);

      authStateController.add(
        const AuthState.authenticated(user: AuthUser(id: "u", provider: "github", providerUserId: "1", providerUsername: "u")),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(factory.callCount, equals(0));
      expect(service.currentStatus, isA<ConnectionDisconnected>());
    });

    test("AuthUnauthenticated disconnects and clears room key (regression)", () async {
      final service = ConnectionService(
        cryptoService,
        roomKeyStorage,
        authTokenProvider,
        authSession,
        lifecycleSource,
        failureReporter,
      );
      addTearDown(service.dispose);

      service.emitStatusForTesting(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "t"),
          health: HealthResponse(healthy: true, version: "1"),
        ),
      );

      authStateController.add(const AuthState.unauthenticated());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.currentStatus, isA<ConnectionDisconnected>());
      verify(roomKeyStorage.clearRoomKey).called(1);
    });
  });
}
