import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/auth/auth_api.dart";
import "package:sesori_bridge/src/auth/bridge_registration_service.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/relay_client.dart";
import "package:sesori_bridge/src/models/bridge_config.dart";
import "package:sesori_bridge/src/orchestrator.dart";
import "package:sesori_bridge/src/routing/bridge_restart_dispatcher.dart";
import "package:sesori_bridge/src/server/services/bridge_restart_service.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel, ServerClock;
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/test_chat_history.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

void main() {
  group("OrchestratorSession bridge registration", () {
    test("startup registration failure fails startup and lifecycle without connecting to the relay", () async {
      final repository = FakeBridgeRegistrationRepository()
        ..registerError = BridgeRegistrationException(statusCode: 500, body: "boom");
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      await expectLater(harness.startFuture, throwsA(isA<BridgeRegistrationException>()));
      await expectLater(harness.runFuture, throwsA(isA<BridgeRegistrationException>()));

      expect(repository.registeredBridgeIds, equals([null]));
      expect(harness.relayServer.connectedClientCount, equals(0));
    });

    test("registers before the initial connect and sends the bridge id in the auth message", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final bridgeSocket = await harness.relayServer.nextClient();
      final authMessage = await _firstTextMessage(bridgeSocket);

      expect(repository.registeredBridgeIds, equals([null]));
      expect(harness.bridgeIdStorage.bridgeId, equals("br_first001"));
      expect(authMessage["type"], equals("auth"));
      expect(authMessage["role"], equals("bridge"));
      expect(authMessage["bridgeId"], equals("br_first001"));
    });

    test("normal disconnect reconnects with a fresh inbound relay iterator", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);
      await firstSocket.close();

      final secondSocket = await harness.relayServer.nextClient();
      final secondMessages = StreamIterator<dynamic>(secondSocket);
      expect(await secondMessages.moveNext(), isTrue);
      final authMessage = jsonDecodeMap(secondMessages.current as String);
      final firstPhoneConnected = harness.session.firstPhoneConnected;

      secondSocket.add(jsonEncode({"type": "phone_connected", "connId": 7}));
      final rawSocketActivatedPhone = await Future.any<bool>([
        firstPhoneConnected.then((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 100), () => false),
      ]);
      expect(rawSocketActivatedPhone, isFalse);

      final phoneKeyPair = await RelayCryptoService().generateKeyPair();
      final phonePublicKey = await phoneKeyPair.extractPublicKey();
      final keyExchange = RelayMessage.keyExchange(
        publicKey: base64Url.encode(phonePublicKey.bytes).replaceAll("=", ""),
      );
      secondSocket.add(<int>[
        0,
        7,
        ...utf8.encode(jsonEncode(keyExchange.toJson())),
      ]);

      expect(await secondMessages.moveNext(), isTrue);
      final response = secondMessages.current;
      expect(response, isA<List<int>>());
      expect((response as List<int>).sublist(0, 2), equals(const [0, 7]));
      await firstPhoneConnected.timeout(const Duration(seconds: 2));
      await secondMessages.cancel();

      expect(repository.registeredBridgeIds, equals([null]), reason: "registration is memoized per process");
      expect(authMessage["bridgeId"], equals("br_first001"));
    });

    test("close code 4006 clears the bridge id and re-registers fresh", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      repository.nextBridgeId = "br_second002";
      await firstSocket.close(RelayCloseCodes.bridgeRevoked);

      final secondSocket = await harness.relayServer.nextClient();
      final authMessage = await _firstTextMessage(secondSocket);

      expect(
        repository.registeredBridgeIds,
        equals([null, null]),
        reason: "the revoked bridge id must not be re-posted",
      );
      expect(harness.bridgeIdStorage.bridgeId, equals("br_second002"));
      expect(authMessage["bridgeId"], equals("br_second002"));
    });

    test("registration failure after 4006 retries the connect attempt on the existing backoff", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      repository
        ..nextBridgeId = "br_second002"
        ..registerError = BridgeRegistrationException(statusCode: 500, body: "boom");
      await firstSocket.close(RelayCloseCodes.bridgeRevoked);

      // First reconnect attempt fails on registration without touching the relay.
      await _waitFor(
        () => repository.registeredBridgeIds.length >= 2,
        reason: "first re-registration attempt",
      );
      expect(harness.relayServer.connectedClientCount, equals(1));

      // Once registration succeeds the next backoff attempt reconnects.
      repository.registerError = null;
      final secondSocket = await harness.relayServer.nextClient(timeout: const Duration(seconds: 10));
      final authMessage = await _firstTextMessage(secondSocket);

      expect(repository.registeredBridgeIds.length, greaterThanOrEqualTo(3));
      expect(authMessage["bridgeId"], equals("br_second002"));
    });

    test("cancellation during re-registration does not open a successor relay connection", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      final registrationGate = Completer<void>();
      repository
        ..nextBridgeId = "br_second002"
        ..registerDelay = registrationGate.future;
      await firstSocket.close(RelayCloseCodes.bridgeRevoked);
      await _waitFor(
        () => repository.registeredBridgeIds.length >= 2,
        reason: "blocked re-registration",
      );

      final cancelFuture = harness.session.cancel();
      registrationGate.complete();
      await cancelFuture;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(harness.relayServer.connectedClientCount, equals(1));
    });

    test("cancellation while the old relay closes does not open a successor connection", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      final closeGate = Completer<void>();
      harness.relayClient.closeDelay = closeGate.future;
      await firstSocket.close();
      await harness.relayClient.closeStarted.future;

      final cancelFuture = harness.session.cancel();
      closeGate.complete();
      await cancelFuture;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(harness.relayServer.connectedClientCount, equals(1));
    });

    test("cancellation while initial connect returns closes the promoted connection", () async {
      final connectReturnGate = Completer<void>();
      final harness = await _RegistrationHarness.start(
        repository: FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001",
        connectReturnDelay: connectReturnGate.future,
      );
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);
      await harness.relayClient.connectPromoted.future;

      final cancelFuture = harness.session.cancel();
      connectReturnGate.complete();
      await cancelFuture;
      await harness.runFuture.timeout(const Duration(seconds: 5));

      expect(
        harness.relayClient.sendIfCurrent(
          connection: harness.relayClient.promotedConnection!,
          connID: 1,
          payload: Uint8List.fromList(const [1]),
        ),
        RelaySendOutcome.stale,
      );
    });
  });

  group("OrchestratorSession routed request boundaries", () {
    test("enqueues the correlated restart response before handoff and graceful close", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_restart001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);
      harness.restartService.restartable = true;
      final phone = await _activatePhone(harness: harness, connId: 7);
      final sendsBeforeRestart = harness.relayClient.sendCount;

      await _sendEncrypted(
        socket: phone.socket,
        connId: 7,
        encryptor: phone.encryptor,
        message: const RelayMessage.request(
          id: "restart-request",
          method: "POST",
          path: "/global/restart",
          headers: {},
          body: null,
        ),
      );

      final response = await _nextResponse(
        messages: phone.messages,
        encryptor: phone.encryptor,
        requestId: "restart-request",
      );
      expect(response.status, 200);
      expect(jsonDecodeMap(response.body!)["restarting"], isTrue);
      expect(harness.restartService.handoffCalls, 1);
      expect(harness.restartService.sendCountAtHandoff, sendsBeforeRestart + 1);
      expect(harness.restartService.connIdAtHandoff, 7);
      await harness.runFuture.timeout(const Duration(seconds: 5));
    });

    test("a current response send failure closes that handle and reconnects", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_sendfail01";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);
      final phone = await _activatePhone(harness: harness, connId: 8);
      harness.relayClient.failNextSend = true;

      await _sendEncrypted(
        socket: phone.socket,
        connId: 8,
        encryptor: phone.encryptor,
        message: const RelayMessage.request(
          id: "send-failure-request",
          method: "GET",
          path: "/global/health",
          headers: {},
          body: null,
        ),
      );

      final successor = await harness.relayServer.nextClient(timeout: const Duration(seconds: 5));
      final authMessage = await _firstTextMessage(successor);
      expect(authMessage["bridgeId"], "br_sendfail01");
    });

    test("a stale routed response does not count unsent bandwidth", () async {
      final harness = await _RegistrationHarness.start(
        repository: FakeBridgeRegistrationRepository()..nextBridgeId = "br_stale001",
      );
      addTearDown(harness.close);
      final phone = await _activatePhone(harness: harness, connId: 10);
      final sentByteCounts = <int>[];
      final subscription = harness.session.bytesSent.listen(sentByteCounts.add);
      addTearDown(subscription.cancel);
      harness.relayClient.staleNextSend = true;

      await _sendEncrypted(
        socket: phone.socket,
        connId: 10,
        encryptor: phone.encryptor,
        message: const RelayMessage.request(
          id: "stale-response-request",
          method: "GET",
          path: "/global/health",
          headers: {},
          body: null,
        ),
      );
      await _waitFor(() => !harness.relayClient.staleNextSend, reason: "stale response attempt");

      expect(sentByteCounts, isEmpty);
    });

    test("routed and control diagnostics retain useful local context", () async {
      late _RegistrationHarness harness;
      final output = await _captureLogOutput(() async {
        harness = await _RegistrationHarness.start(
          repository: FakeBridgeRegistrationRepository()..nextBridgeId = "br_logs001",
        );
        try {
          final phone = await _activatePhone(harness: harness, connId: 9);
          await _sendEncrypted(
            socket: phone.socket,
            connId: 9,
            encryptor: phone.encryptor,
            message: const RelayMessage.sessionView(sessionId: "private-session-view"),
          );
          await _sendEncrypted(
            socket: phone.socket,
            connId: 9,
            encryptor: phone.encryptor,
            message: const RelayMessage.sseSubscribe(path: "/events/private-subscription-path"),
          );
          await _sendEncrypted(
            socket: phone.socket,
            connId: 9,
            encryptor: phone.encryptor,
            message: const RelayMessage.request(
              id: "health-request",
              method: "GET",
              path: "/global/health?private-route-query=yes",
              headers: {},
              body: null,
            ),
          );

          final response = await _nextResponse(
            messages: phone.messages,
            encryptor: phone.encryptor,
            requestId: "health-request",
          );
          expect(response.status, 200);
        } finally {
          await harness.close();
        }
      });

      expect(output, contains("SessionView connID=9 sessionId=private-session-view"));
      expect(output, contains("SseSubscribe: path=/events/private-subscription-path"));
      expect(output, contains("GET /global/health?private-route-query=yes"));
    });
  });

  group("OrchestratorSession relay takeover (ADR A22)", () {
    test("a 4007 replaced-close does not reconnect within the war window", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(
        repository: repository,
        backoffPolicy: _takeoverHoldoffBackoff,
      );
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // The relay displaces this bridge: another bridge for the account took
      // the slot. The displaced bridge must NOT tight-loop back — it uses a
      // long backoff, so no reconnect happens within the war window.
      await firstSocket.close(RelayCloseCodes.bridgeReplaced, "replaced");

      // The injected takeover backoff is minutes-order while the ordinary
      // backoff is 50ms, so any wrongful reconnect would appear almost
      // immediately — long before this 400ms wait elapses.
      await expectLater(
        harness.relayServer.nextClient(timeout: const Duration(milliseconds: 400)),
        throwsA(isA<TimeoutException>()),
        reason: "displaced bridge must not reconnect on a tight loop",
      );
      expect(harness.relayServer.connectedClientCount, equals(1));
    });

    test("the 1000/replaced rollout fallback also holds off reconnect", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(
        repository: repository,
        backoffPolicy: _takeoverHoldoffBackoff,
      );
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      await firstSocket.close(1000, "replaced");

      await expectLater(
        harness.relayServer.nextClient(timeout: const Duration(milliseconds: 400)),
        throwsA(isA<TimeoutException>()),
        reason: "the rollout fallback (1000/replaced) must be treated as a takeover",
      );
      expect(harness.relayServer.connectedClientCount, equals(1));
    });

    test("cancel wakes a long takeover backoff promptly (no shutdown stall)", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // Displace the bridge: it enters the minutes-order takeover backoff.
      await firstSocket.close(RelayCloseCodes.bridgeReplaced, "replaced");
      // Give the loop a moment to settle into the long Future.delayed wait.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // A SIGTERM-style cancel must wake the loop immediately, not wait out the
      // 2+ minute backoff. The lifecycle should stop well within a few seconds.
      final sw = Stopwatch()..start();
      await harness.session.cancel();
      await harness.runFuture.timeout(const Duration(seconds: 10));
      sw.stop();

      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 10)),
        reason: "cancel must not block on the long takeover backoff",
      );
    });

    test("a plain normal drop (1000, no replaced reason) reconnects promptly", () async {
      final repository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_first001";
      final harness = await _RegistrationHarness.start(repository: repository);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // A vanilla close (network blip / relay restart) is not a takeover and
      // must reconnect on the ordinary 1s-reset backoff, unchanged by this PR.
      await firstSocket.close();

      final secondSocket = await harness.relayServer.nextClient(timeout: const Duration(seconds: 5));
      final authMessage = await _firstTextMessage(secondSocket);
      expect(authMessage["bridgeId"], equals("br_first001"));
    });
  });
}

Future<Map<String, dynamic>> _firstTextMessage(WebSocket socket) async {
  final message = await socket.firstWhere((dynamic data) => data is String).timeout(const Duration(seconds: 5));
  return jsonDecodeMap(message as String);
}

/// Takeover closes must hold off reconnect: the injected takeover backoff is
/// minutes-order, while the ordinary backoff stays fast so a regression to
/// the ordinary reconnect path surfaces within a few hundred milliseconds.
const ReconnectBackoffPolicy _takeoverHoldoffBackoff = ReconnectBackoffPolicy(
  ordinaryInitial: Duration(milliseconds: 50),
  ordinaryMax: Duration(seconds: 1),
  takeoverInitial: Duration(minutes: 5),
  takeoverMax: Duration(minutes: 5),
);

/// Fast ordinary reconnect backoff for registration/reconnect scenarios: none
/// of these tests assert the production 1s cadence, only the reconnect
/// behavior. The takeover durations stay at production defaults so the
/// cancel-wakes-long-backoff test remains meaningful.
const ReconnectBackoffPolicy _registrationTestBackoff = ReconnectBackoffPolicy(
  ordinaryInitial: Duration(milliseconds: 50),
  ordinaryMax: Duration(seconds: 1),
  takeoverInitial: Duration(minutes: 2),
  takeoverMax: Duration(minutes: 5),
);

Future<void> _waitFor(bool Function() condition, {required String reason}) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(timeoutAt)) {
      fail("Timed out waiting for: $reason");
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _RegistrationHarness._({
  required final FakeBridgePlugin plugin,
  required final FakeBridgeIdStorage bridgeIdStorage,
  required final OrchestratorSession session,
  required final Future<OrchestratorSessionStartResult> startFuture,
  required final Future<void> runFuture,
  required final _CountingRelayServer relayServer,
  required final AppDatabase database,
  required final PluginLifecycleService lifecycleService,
  required final http.Client httpClient,
  required final _RecordingRelayClient relayClient,
  required final _RecordingRestartService restartService,
  required final BridgeRestartDispatcher restartDispatcher,
}) {
  static Future<_RegistrationHarness> start({
    required FakeBridgeRegistrationRepository repository,
    Future<void>? connectReturnDelay,
    ReconnectBackoffPolicy backoffPolicy = _registrationTestBackoff,
  }) async {
    final relayServer = await _CountingRelayServer.start();
    final database = createTestDatabase();
    final plugin = FakeBridgePlugin();
    final bridgeIdStorage = FakeBridgeIdStorage();
    final registrationService = BridgeRegistrationService(
      repository: repository,
      tokenRefresher: FakeTokenRefresher(),
      bridgeIdStorage: bridgeIdStorage,
      hostName: "test-host",
      platform: "macos",
    );
    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    final httpClient = http.Client();
    final relayClient = _RecordingRelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: registrationService,
      connectReturnDelay: connectReturnDelay,
    );
    final restartService = _RecordingRestartService(relayClient: relayClient);

    final testChatHistory = createTestChatHistory();
    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      pluginLifecycleRepository: lifecycleRepositoryForLifecycleService(service: lifecycleService),
      pluginLifecycleService: lifecycleService,
      pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
      bridgeSettingsRepository: settingsRepositoryForLifecycleService(service: lifecycleService),
      clock: const ServerClock(),
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      attachmentSpillStorage: testChatHistory.spillStorage,
      archivedSessionStorage: testChatHistory.archivedStorage,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: FakeTokenRefresher(),
      bridgeRegistrationService: registrationService,
      failureReporter: FakeFailureReporter(),
      restartService: restartService,
      filesystemAccessOk: true,
      statusNotifier: null,
      reconnectBackoff: backoffPolicy,
    );

    final composition = orchestrator.create();
    final session = composition.session;
    final startFuture = session.start();
    final runFuture = session.waitUntilStopped();
    startFuture.ignore();
    runFuture.ignore();

    return _RegistrationHarness._(
      plugin: plugin,
      bridgeIdStorage: bridgeIdStorage,
      session: session,
      startFuture: startFuture,
      runFuture: runFuture,
      relayServer: relayServer,
      database: database,
      lifecycleService: lifecycleService,
      httpClient: httpClient,
      relayClient: relayClient,
      restartService: restartService,
      restartDispatcher: composition.restartDispatcher,
    );
  }

  Future<void> close() async {
    await session.cancel();
    try {
      await startFuture.timeout(const Duration(seconds: 10));
    } on Object {
      // Startup may have already completed with the error under test.
    }
    try {
      await runFuture.timeout(const Duration(seconds: 10));
    } on Object {
      // The lifecycle may have already completed with the error under test.
    }
    await lifecycleService.dispose();
    await restartDispatcher.dispose();
    httpClient.close();
    await database.close();
    await relayServer.close();
  }
}

class _RecordingRelayClient({
  required super.relayURL,
  required super.accessTokenProvider,
  required super.bridgeIdProvider,
  required final Future<void>? connectReturnDelay,
}) extends RelayClient {
  int sendCount = 0;
  int? lastConnId;
  bool failNextSend = false;
  bool staleNextSend = false;
  final Completer<void> connectPromoted = Completer<void>();
  RelayConnection? promotedConnection;
  Future<void>? closeDelay;
  final Completer<void> closeStarted = Completer<void>();

  @override
  Future<RelayConnection> connect() async {
    final connection = await super.connect();
    promotedConnection = connection;
    if (!connectPromoted.isCompleted) {
      connectPromoted.complete();
    }
    await connectReturnDelay;
    return connection;
  }

  @override
  Future<RelayCloseOutcome> closeIfCurrent({required RelayConnection connection}) async {
    final closeFuture = super.closeIfCurrent(connection: connection);
    if (!closeStarted.isCompleted) {
      closeStarted.complete();
    }
    await closeDelay;
    return await closeFuture;
  }

  @override
  RelaySendOutcome sendIfCurrent({
    required RelayConnection connection,
    required int connID,
    required Uint8List payload,
  }) {
    if (failNextSend) {
      failNextSend = false;
      throw StateError("send failed intentionally");
    }
    if (staleNextSend) {
      staleNextSend = false;
      return RelaySendOutcome.stale;
    }
    final outcome = super.sendIfCurrent(
      connection: connection,
      connID: connID,
      payload: payload,
    );
    if (outcome == RelaySendOutcome.stale) return outcome;
    sendCount++;
    lastConnId = connID;
    return outcome;
  }
}

class _RecordingRestartService({required final _RecordingRelayClient relayClient}) implements BridgeRestartService {
  bool restartable = false;
  int handoffCalls = 0;
  int? sendCountAtHandoff;
  int? connIdAtHandoff;

  @override
  Future<bool> canRestart() async => restartable;

  @override
  Future<bool> canSpawnSuccessor() async => restartable;

  @override
  Future<bool> performRestartHandoff() async {
    handoffCalls++;
    sendCountAtHandoff = relayClient.sendCount;
    connIdAtHandoff = relayClient.lastConnId;
    return true;
  }

  @override
  Future<bool> spawnSuccessor() async => true;
}

Future<({WebSocket socket, StreamIterator<dynamic> messages, SessionEncryptor encryptor})> _activatePhone({
  required _RegistrationHarness harness,
  required int connId,
}) async {
  final socket = await harness.relayServer.nextClient();
  final messages = StreamIterator<dynamic>(socket);
  expect(await messages.moveNext(), isTrue);
  expect(jsonDecodeMap(messages.current as String)["type"], "auth");

  final crypto = RelayCryptoService();
  final phoneKeyPair = await crypto.generateKeyPair();
  final phonePublicKey = await phoneKeyPair.extractPublicKey();
  socket.add(<int>[
    0,
    connId,
    ...utf8.encode(
      jsonEncode(
        RelayMessage.keyExchange(
          publicKey: base64Url.encode(phonePublicKey.bytes).replaceAll("=", ""),
        ).toJson(),
      ),
    ),
  ]);

  expect(await messages.moveNext(), isTrue);
  final readyFrame = messages.current as List<int>;
  expect(readyFrame.sublist(0, 2), [0, connId]);
  final ready = await _decryptReady(response: readyFrame.sublist(2), phoneKeyPair: phoneKeyPair);
  final roomKey = SecretKey(base64Url.decode(base64Url.normalize(ready.roomKey)));
  await harness.session.firstPhoneConnected.timeout(const Duration(seconds: 2));
  return (socket: socket, messages: messages, encryptor: crypto.createSessionEncryptor(roomKey));
}

Future<RelayReady> _decryptReady({required List<int> response, required SimpleKeyPair phoneKeyPair}) async {
  final crypto = RelayCryptoService();
  final bridgePublicKey = SimplePublicKey(response.sublist(0, 32), type: KeyPairType.x25519);
  final secret = await crypto.deriveSharedSecret(phoneKeyPair, peerPublicKey: bridgePublicKey);
  final encryptor = crypto.createSessionEncryptor(await crypto.deriveEncryptionKey(secret));
  final decrypted = await unframe(response.sublist(32), encryptor: encryptor);
  return RelayMessage.fromJson(jsonDecodeMap(utf8.decode(decrypted))) as RelayReady;
}

Future<void> _sendEncrypted({
  required WebSocket socket,
  required int connId,
  required SessionEncryptor encryptor,
  required RelayMessage message,
}) async {
  final payload = await frame(utf8.encode(jsonEncode(message.toJson())), encryptor: encryptor);
  socket.add(<int>[0, connId, ...payload]);
}

Future<RelayResponse> _nextResponse({
  required StreamIterator<dynamic> messages,
  required SessionEncryptor encryptor,
  required String requestId,
}) async {
  while (await messages.moveNext()) {
    final wire = messages.current;
    if (wire is! List<int> || wire.length < 3) continue;
    final decrypted = await unframe(wire.sublist(2), encryptor: encryptor);
    final message = RelayMessage.fromJson(jsonDecodeMap(utf8.decode(decrypted)));
    if (message case final RelayResponse response when response.id == requestId) return response;
  }
  throw StateError("relay closed before response $requestId");
}

Future<String> _captureLogOutput(Future<void> Function() action) async {
  final stderrBuffer = BufferingStdout();
  final previousLevel = Log.level;
  try {
    Log.level = LogLevel.verbose;
    await IOOverrides.runZoned(action, stderr: () => stderrBuffer);
    return stderrBuffer.text;
  } finally {
    Log.level = previousLevel;
  }
}

/// A [TestRelayServer] that also counts how many clients ever connected.
class _CountingRelayServer._(final TestRelayServer _inner) {
  int connectedClientCount = 0;

  static Future<_CountingRelayServer> start() async {
    return _CountingRelayServer._(await TestRelayServer.start());
  }

  int get port => _inner.port;

  Future<WebSocket> nextClient({Duration timeout = const Duration(seconds: 5)}) async {
    final socket = await _inner.nextClient().timeout(timeout);
    connectedClientCount += 1;
    return socket;
  }

  Future<void> close() => _inner.close();
}
