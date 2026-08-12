import "dart:async";
import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/logging/logging.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockRelayCryptoService() extends Mock implements RelayCryptoService;

class _MockRoomKeyStorage() extends Mock implements RoomKeyStorage;

class _MockAuthTokenProvider() extends Mock implements AuthTokenProvider;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockLifecycleSource() extends Mock implements LifecycleSource;

class _MockFailureReporter() extends Mock implements FailureReporter;

class _MockRelayClient() extends Mock implements RelayClient;

class _TestRelayClientFactory({required final RelayClient _client}) extends RelayClientFactory {
  @override
  RelayClient call({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
  }) => _client;
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(
      const RelayRequest(
        id: "fallback",
        method: "GET",
        path: "/health",
        headers: {},
        body: null,
      ),
    );
  });

  group("ConnectionService SSE parsing", () {
    late BehaviorSubject<LifecycleState> lifecycleController;
    late BehaviorSubject<AuthState> authStateController;
    late StreamController<RelaySseEvent> sseController;
    late _MockFailureReporter failureReporter;
    late ConnectionService service;

    const config = ServerConnectionConfig(
      relayHost: "relay.example.com",
      authToken: "token",
    );
    const health = HealthResponse(healthy: true, version: "1.0.0", filesystemAccessDegraded: null);

    setUp(() {
      lifecycleController = BehaviorSubject<LifecycleState>.seeded(LifecycleState.resumed);
      authStateController = BehaviorSubject<AuthState>.seeded(const AuthState.initial());
      sseController = StreamController<RelaySseEvent>.broadcast();

      final lifecycleSource = _MockLifecycleSource();
      final authSession = _MockAuthSession();
      failureReporter = _MockFailureReporter();
      final relayClient = _MockRelayClient();

      when(() => lifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycleController.stream);
      when(() => authSession.authStateStream).thenAnswer((_) => authStateController.stream);
      when(relayClient.connect).thenAnswer((_) async {});
      when(() => relayClient.didResume).thenReturn(false);
      when(() => relayClient.isConnected).thenReturn(true);
      when(() => relayClient.connectionState).thenReturn(RelayClientConnectionState.connected);
      when(() => relayClient.sendRequest(any())).thenAnswer(
        (_) async => RelayResponse(
          id: "health",
          status: 200,
          body: jsonEncode(health.toJson()),
          headers: const {},
        ),
      );
      when(() => relayClient.subscribeSse(any())).thenAnswer((_) => sseController.stream);
      when(() => relayClient.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
      when(relayClient.disconnect).thenAnswer((_) async {});

      service = ConnectionService(
        _MockRelayCryptoService(),
        _MockRoomKeyStorage(),
        _MockAuthTokenProvider(),
        authSession,
        lifecycleSource,
        failureReporter,
        relayClientFactory: _TestRelayClientFactory(client: relayClient),
      );
    });

    tearDown(() async {
      service.dispose();
      await Future<void>.delayed(Duration.zero);
      await sseController.close();
      await lifecycleController.close();
      await authStateController.close();
    });

    test("ignores an unknown event type without reporting and continues", () async {
      final previousLogLevel = logLevel;
      setLogLevel(LogLevel.warning);
      addTearDown(() => setLogLevel(previousLogLevel));

      final logs = <String>[];
      final unknownEventLogged = Completer<void>();

      await runZoned(
        () async {
          final result = await service.connect(config);
          expect(result, isA<SuccessResponse<HealthResponse>>());

          final nextKnownEvent = service.events.first;
          sseController.add(
            RelaySseEvent(
              data: jsonEncode({
                "payload": {
                  "type": "plugin.future.changed",
                  "properties": {"snapshotToken": "future-token"},
                },
              }),
            ),
          );
          await unknownEventLogged.future.timeout(const Duration(seconds: 1));

          verifyNever(
            () => failureReporter.recordFailure(
              error: any(named: "error"),
              stackTrace: any(named: "stackTrace"),
              uniqueIdentifier: any(named: "uniqueIdentifier"),
              fatal: any(named: "fatal"),
              reason: any(named: "reason"),
              information: any(named: "information"),
            ),
          );

          sseController.add(
            RelaySseEvent(
              data: jsonEncode({
                "payload": {"type": "server.heartbeat", "properties": <String, Object?>{}},
              }),
            ),
          );

          final event = await nextKnownEvent.timeout(const Duration(seconds: 1));
          expect(event.data, isA<SesoriServerHeartbeat>());
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logs.add(line);
            if (line.contains("Ignoring unknown SSE event type: plugin.future.changed") &&
                !unknownEventLogged.isCompleted) {
              unknownEventLogged.complete();
            }
          },
        ),
      );

      expect(logs, contains(contains("Ignoring unknown SSE event type: plugin.future.changed")));
    });

    test("still reports a malformed payload for a known event type", () async {
      final previousLogLevel = logLevel;
      setLogLevel(LogLevel.none);
      addTearDown(() => setLogLevel(previousLogLevel));

      final failureReported = Completer<void>();
      when(
        () => failureReporter.recordFailure(
          error: any(named: "error"),
          stackTrace: any(named: "stackTrace"),
          uniqueIdentifier: any(named: "uniqueIdentifier"),
          fatal: any(named: "fatal"),
          reason: any(named: "reason"),
          information: any(named: "information"),
        ),
      ).thenAnswer((_) {
        failureReported.complete();
        return Future<void>.value();
      });

      final result = await service.connect(config);
      expect(result, isA<SuccessResponse<HealthResponse>>());

      sseController.add(
        RelaySseEvent(
          data: jsonEncode({
            "payload": {"type": "plugin.management.changed", "properties": <String, Object?>{}},
          }),
        ),
      );
      await failureReported.future.timeout(const Duration(seconds: 1));

      verify(
        () => failureReporter.recordFailure(
          error: any(named: "error"),
          stackTrace: any(named: "stackTrace"),
          uniqueIdentifier: "sse_parse_failure:plugin.management.changed",
          fatal: false,
          reason: "Unknown or malformed SSE event type: plugin.management.changed",
          information: any(named: "information"),
        ),
      ).called(1);
    });
  });
}
