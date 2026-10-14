import "dart:async";
import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/testing/test_helpers.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockRelayCryptoService() extends Mock implements RelayCryptoService;

class _MockAuthTokenProvider() extends Mock implements AuthTokenProvider;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockLifecycleSource() extends Mock implements LifecycleSource;

class _MockRelayClient() extends Mock implements RelayClient;

/// Hands out [_clients] in order and records the target each was built for.
class _RecordingRelayClientFactory(final List<RelayClient> _clients) extends RelayClientFactory {
  final List<String?> bridgeIds = [];

  @override
  RelayClient call({
    required String relayHost,
    required RelayCryptoService cryptoService,
    required RoomKeyStorage roomKeyStorage,
    required String? authToken,
    required String? bridgeId,
  }) {
    bridgeIds.add(bridgeId);
    return _clients[bridgeIds.length - 1];
  }
}

const _health = HealthResponse(healthy: true, version: "1.0.0", filesystemAccessDegraded: false);
const _user = AuthUser(id: "u", provider: AuthProvider.github, providerUserId: "1", providerUsername: "u");

ServerConnectionConfig _config({required String? bridgeId}) =>
    ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token", bridgeId: bridgeId);

_MockRelayClient _connectedClient({
  required Stream<RelaySseEvent> sse,
  required String? reportedBridgeId,
}) {
  final client = _MockRelayClient();
  when(client.connect).thenAnswer((_) async {});
  when(() => client.didResume).thenReturn(false);
  when(() => client.isConnected).thenReturn(true);
  when(() => client.connectionState).thenReturn(RelayClientConnectionState.connected);
  when(() => client.reportedBridgeId).thenReturn(reportedBridgeId);
  when(
    () => client.sendRequest(
      request: any(named: "request"),
      timeout: any(named: "timeout"),
    ),
  ).thenAnswer((_) async => RelayResponse(id: "h", status: 200, body: jsonEncode(_health.toJson()), headers: const {}));
  when(() => client.subscribeSse(any())).thenAnswer((_) => sse);
  when(() => client.bridgeStatus).thenAnswer((_) => const Stream<BridgeStatus>.empty());
  when(() => client.bridgePresence).thenAnswer((_) => const Stream<BridgePresenceMessage>.empty());
  when(client.disconnect).thenAnswer((_) async {});
  return client;
}

RelaySseEvent _heartbeat() => RelaySseEvent(
  data: jsonEncode({
    "payload": {"type": "server.heartbeat", "properties": <String, Object?>{}},
  }),
);

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(const RelayRequest(id: "fb", method: "GET", path: "/health", headers: {}, body: null));
  });

  late BehaviorSubject<LifecycleState> lifecycle;
  late BehaviorSubject<AuthState> auth;
  late MockRoomKeyStorage roomKeyStorage;
  late _MockAuthTokenProvider authTokenProvider;
  late FakeTargetBridgeStorage targetStorage;

  setUp(() {
    lifecycle = BehaviorSubject.seeded(LifecycleState.resumed);
    auth = BehaviorSubject.seeded(const AuthState.initial());
    roomKeyStorage = MockRoomKeyStorage();
    authTokenProvider = _MockAuthTokenProvider();
    targetStorage = FakeTargetBridgeStorage();
    when(roomKeyStorage.clearRoomKey).thenAnswer((_) async {});
    when(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl"))).thenAnswer((_) async => "token");
  });

  tearDown(() async {
    await lifecycle.close();
    await auth.close();
  });

  ConnectionService buildService({required RelayClientFactory factory}) {
    final authSession = _MockAuthSession();
    final lifecycleSource = _MockLifecycleSource();
    when(() => authSession.authStateStream).thenAnswer((_) => auth.stream);
    when(() => lifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycle.stream);
    final service = ConnectionService(
      _MockRelayCryptoService(),
      roomKeyStorage,
      targetStorage,
      authTokenProvider,
      authSession,
      lifecycleSource,
      MockFailureReporter(),
      relayClientFactory: factory,
    );
    addTearDown(service.dispose);
    return service;
  }

  test("the connect after sign-in targets the stored computer", () async {
    await targetStorage.write(bridgeId: "b");
    final factory = _RecordingRelayClientFactory([
      _connectedClient(sse: NeverStream(), reportedBridgeId: "b"),
    ]);
    final service = buildService(factory: factory);

    auth.add(const AuthState.authenticated(user: _user));
    await service.status.firstWhere((status) => status is ConnectionConnected);

    expect(factory.bridgeIds, ["b"]);
    expect(service.currentStatus.targetBridgeId, "b");
  });

  test("forwards presence notices about other computers from the live socket", () async {
    await targetStorage.write(bridgeId: "b");
    final notices = StreamController<BridgePresenceMessage>.broadcast();
    addTearDown(notices.close);
    final client = _connectedClient(sse: NeverStream(), reportedBridgeId: "b");
    when(() => client.bridgePresence).thenAnswer((_) => notices.stream);
    final service = buildService(factory: _RecordingRelayClientFactory([client]));
    auth.add(const AuthState.authenticated(user: _user));
    await service.status.firstWhere((status) => status is ConnectionConnected);

    final forwarded = service.bridgePresence.first;
    notices.add(const BridgePresenceMessage(bridgeId: "c", online: true));

    expect(await forwarded, const BridgePresenceMessage(bridgeId: "c", online: true));
    expect(service.currentStatus, isA<ConnectionConnected>(), reason: "presence never changes the connection");
  });

  test("signing out clears the stored target", () async {
    await targetStorage.write(bridgeId: "b");
    buildService(factory: _RecordingRelayClientFactory([]));

    auth.add(const AuthState.unauthenticated());
    await pumpEventQueue();

    expect(targetStorage.stored, isNull);
  });

  test("an unpinned connection adopts the reported computer without reconnecting", () async {
    final factory = _RecordingRelayClientFactory([
      _connectedClient(sse: NeverStream(), reportedBridgeId: "a"),
    ]);
    final service = buildService(factory: factory);

    await service.connect(_config(bridgeId: null));
    await pumpEventQueue();

    expect(service.currentStatus, isA<ConnectionConnected>());
    expect(service.currentStatus.targetBridgeId, "a");
    expect(targetStorage.stored, "a");
    expect(factory.bridgeIds, [null]);
  });

  test("adoption keeps a computer chosen while the unpinned connection was joining", () async {
    final factory = _RecordingRelayClientFactory([
      _connectedClient(sse: NeverStream(), reportedBridgeId: "a"),
    ]);
    final service = buildService(factory: factory);
    final joining = service.connect(_config(bridgeId: null));

    await service.retarget(bridgeId: "b");
    await joining;
    await pumpEventQueue();

    expect(targetStorage.stored, "b");
  });

  test("retarget stores the computer and reconnects to it", () async {
    final oldSse = StreamController<RelaySseEvent>.broadcast();
    addTearDown(oldSse.close);
    final oldClient = _connectedClient(sse: oldSse.stream, reportedBridgeId: "a");
    final factory = _RecordingRelayClientFactory([
      oldClient,
      _connectedClient(sse: NeverStream(), reportedBridgeId: "b"),
    ]);
    final service = buildService(factory: factory);
    await service.connect(_config(bridgeId: "a"));
    final events = <SseEvent>[];
    final subscription = service.events.listen(events.add);
    addTearDown(subscription.cancel);
    final token = Completer<String?>();
    when(() => authTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl"))).thenAnswer((_) => token.future);

    final retargeted = service.retarget(bridgeId: "b");

    // The reset is announced at once, before the new computer answers.
    expect(service.currentStatus, isA<ConnectionReconnecting>());
    expect(service.currentStatus.targetBridgeId, "b");
    // A late event from the previous computer reaches nobody, even while the
    // reconnect is still waiting for its token.
    oldSse.add(_heartbeat());
    await pumpEventQueue();
    expect(events, isEmpty);
    token.complete("token");
    await retargeted;
    await service.status.firstWhere((status) => status is ConnectionConnected);

    expect(targetStorage.stored, "b");
    expect(factory.bridgeIds, ["a", "b"]);
    expect(service.currentStatus.targetBridgeId, "b");
    verify(oldClient.disconnect).called(1);
  });

  test("retarget while disconnected only stores the computer", () async {
    final factory = _RecordingRelayClientFactory([]);
    final service = buildService(factory: factory);

    await service.retarget(bridgeId: "b");

    expect(targetStorage.stored, "b");
    expect(factory.bridgeIds, isEmpty);
    expect(service.currentStatus, isA<ConnectionDisconnected>());
  });
}
