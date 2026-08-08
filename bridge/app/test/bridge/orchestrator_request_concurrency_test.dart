import "dart:async";
import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/server/services/bridge_restart_service.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/test_chat_history.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

void main() {
  group("OrchestratorSession concurrent relay requests", () {
    test("a stalled request does not block same-client health or another client's control flow", () async {
      final harness = await _ConcurrencyHarness.start();
      addTearDown(harness.close);
      await harness.insertSession(sessionId: "stalled-session");
      final firstPhone = await harness.activatePhone(connId: 11);
      final routeStarted = Completer<void>();
      final routeGate = Completer<void>();
      harness.plugin
        ..messagesStarted = routeStarted
        ..messagesDelay = routeGate.future;

      await harness.sendEncrypted(
        connId: 11,
        encryptor: firstPhone,
        message: RelayMessage.request(
          id: "stalled-request",
          method: "POST",
          path: "/session/messages",
          headers: const {},
          body: jsonEncode(const SessionIdRequest(sessionId: "stalled-session").toJson()),
        ),
      );
      await routeStarted.future.timeout(const Duration(seconds: 2));

      try {
        final secondPhone = await harness.activatePhone(connId: 22);
        harness.disconnectPhone(connId: 22);
        await harness.resumePhone(connId: 22, encryptor: secondPhone);

        await harness.sendEncrypted(
          connId: 11,
          encryptor: firstPhone,
          message: const RelayMessage.request(
            id: "health-request",
            method: "GET",
            path: "/global/health",
            headers: {},
            body: null,
          ),
        );
        final health = await harness.nextResponse(
          connId: 11,
          encryptor: firstPhone,
          requestId: "health-request",
        );

        expect(health.status, 200);
        expect(routeGate.isCompleted, isFalse);

        routeGate.complete();
        final stalled = await harness.nextResponse(
          connId: 11,
          encryptor: firstPhone,
          requestId: "stalled-request",
        );
        expect(stalled.status, 200);
      } finally {
        if (!routeGate.isCompleted) routeGate.complete();
      }
    });

    test("phone disconnect and rekey fence a reused connId without suppressing restart", () async {
      final harness = await _ConcurrencyHarness.start();
      addTearDown(harness.close);
      final originalPhone = await harness.activatePhone(connId: 31);
      final preflightStarted = Completer<void>();
      final preflightGate = Completer<void>();
      harness.restartService
        ..restartable = true
        ..canRestartStarted = preflightStarted
        ..canRestartDelay = preflightGate.future;

      await harness.sendEncrypted(
        connId: 31,
        encryptor: originalPhone,
        message: const RelayMessage.request(
          id: "stale-restart",
          method: "POST",
          path: "/global/restart",
          headers: {},
          body: null,
        ),
      );
      await preflightStarted.future.timeout(const Duration(seconds: 2));

      try {
        harness.disconnectPhone(connId: 31);
        await harness.activatePhone(connId: 31);
        final sendsBeforeCompletion = harness.relayClient.sendCount;
        final attemptsBeforeCompletion = harness.relayClient.sendAttempts.length;

        preflightGate.complete();
        await harness.restartService.handoffPerformed.future.timeout(const Duration(seconds: 2));

        expect(harness.restartService.handoffCalls, 1);
        expect(harness.restartService.sendCountAtHandoff, sendsBeforeCompletion);
        expect(harness.restartService.sendAttemptCountAtHandoff, attemptsBeforeCompletion);
        await harness.runFuture.timeout(const Duration(seconds: 5));
      } finally {
        if (!preflightGate.isCompleted) preflightGate.complete();
      }
    });

    test("relay reconnect fences an old response from a successor reusing the connId", () async {
      final harness = await _ConcurrencyHarness.start();
      addTearDown(harness.close);
      final originalPhone = await harness.activatePhone(connId: 41);
      final preflightStarted = Completer<void>();
      final preflightGate = Completer<void>();
      harness.restartService
        ..restartable = true
        ..canRestartStarted = preflightStarted
        ..canRestartDelay = preflightGate.future;

      await harness.sendEncrypted(
        connId: 41,
        encryptor: originalPhone,
        message: const RelayMessage.request(
          id: "old-epoch-restart",
          method: "POST",
          path: "/global/restart",
          headers: {},
          body: null,
        ),
      );
      await preflightStarted.future.timeout(const Duration(seconds: 2));

      try {
        await harness.reconnectRelay();
        await harness.activatePhone(connId: 41);
        final sendsBeforeCompletion = harness.relayClient.sendCount;
        final attemptsBeforeCompletion = harness.relayClient.sendAttempts.length;

        preflightGate.complete();
        await harness.restartService.handoffPerformed.future.timeout(const Duration(seconds: 2));

        expect(harness.restartService.handoffCalls, 1);
        expect(harness.restartService.sendCountAtHandoff, sendsBeforeCompletion);
        expect(harness.restartService.sendAttemptCountAtHandoff, attemptsBeforeCompletion);
        await harness.runFuture.timeout(const Duration(seconds: 5));
      } finally {
        if (!preflightGate.isCompleted) preflightGate.complete();
      }
    });

    test("restart dispatch follows a synchronously claimed current send failure", () async {
      final harness = await _ConcurrencyHarness.start();
      addTearDown(harness.close);
      final phone = await harness.activatePhone(connId: 51);
      final closeGate = Completer<void>();
      harness.restartService.restartable = true;
      harness.relayClient
        ..closeDelay = closeGate.future
        ..failNextSend = true;
      final sendsBeforeRestart = harness.relayClient.sendCount;
      final attemptsBeforeRestart = harness.relayClient.sendAttempts.length;

      await harness.sendEncrypted(
        connId: 51,
        encryptor: phone,
        message: const RelayMessage.request(
          id: "send-failure-restart",
          method: "POST",
          path: "/global/restart",
          headers: {},
          body: null,
        ),
      );

      try {
        await harness.restartService.handoffPerformed.future.timeout(const Duration(seconds: 2));

        expect(harness.restartService.handoffCalls, 1);
        expect(harness.restartService.sendCountAtHandoff, sendsBeforeRestart);
        expect(harness.restartService.sendAttemptCountAtHandoff, attemptsBeforeRestart + 1);
        expect(harness.restartService.closeAttemptCountAtHandoff, 1);
        expect(harness.relayClient.closeStarted.isCompleted, isTrue);
        expect(closeGate.isCompleted, isFalse, reason: "restart must not await the close handshake");
      } finally {
        if (!closeGate.isCompleted) closeGate.complete();
      }
      await harness.runFuture.timeout(const Duration(seconds: 5));
    });

    test("shutdown drains accepted work and prevents its late response send", () async {
      final harness = await _ConcurrencyHarness.start();
      addTearDown(harness.close);
      await harness.insertSession(sessionId: "shutdown-session");
      final phone = await harness.activatePhone(connId: 61);
      final routeStarted = Completer<void>();
      final routeGate = Completer<void>();
      harness.plugin
        ..messagesStarted = routeStarted
        ..messagesDelay = routeGate.future;

      await harness.sendEncrypted(
        connId: 61,
        encryptor: phone,
        message: RelayMessage.request(
          id: "shutdown-request",
          method: "POST",
          path: "/session/messages",
          headers: const {},
          body: jsonEncode(const SessionIdRequest(sessionId: "shutdown-session").toJson()),
        ),
      );
      await routeStarted.future.timeout(const Duration(seconds: 2));
      final sendsAtShutdown = harness.relayClient.sendCount;
      final attemptsAtShutdown = harness.relayClient.sendAttempts.length;
      var stopped = false;
      harness.runFuture.then((_) => stopped = true).ignore();

      try {
        await harness.composition.session.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(stopped, isFalse);

        routeGate.complete();
        await harness.runFuture.timeout(const Duration(seconds: 5));
        expect(harness.relayClient.sendCount, sendsAtShutdown);
        expect(harness.relayClient.sendAttempts.length, attemptsAtShutdown);
      } finally {
        if (!routeGate.isCompleted) routeGate.complete();
      }
    });
  });
}

class _ConcurrencyHarness {
  final _BlockingMessagesPlugin plugin;
  final OrchestratorComposition composition;
  final Future<void> runFuture;
  final TestRelayServer relayServer;
  final AppDatabase database;
  final PluginLifecycleService lifecycleService;
  final http.Client httpClient;
  final BridgeRuntime runtime;
  final _RecordingRelayClient relayClient;
  final _RecordingRestartService restartService;

  WebSocket _socket;
  StreamIterator<dynamic> _messages;

  _ConcurrencyHarness._({
    required this.plugin,
    required this.composition,
    required this.runFuture,
    required this.relayServer,
    required this.database,
    required this.lifecycleService,
    required this.httpClient,
    required this.runtime,
    required this.relayClient,
    required this.restartService,
    required WebSocket socket,
    required StreamIterator<dynamic> messages,
  }) : _socket = socket,
       _messages = messages;

  static Future<_ConcurrencyHarness> start() async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final plugin = _BlockingMessagesPlugin();
    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    final httpClient = http.Client();
    final registrationService = createFakeBridgeRegistrationService();
    final relayClient = _RecordingRelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: registrationService,
    );
    final restartService = _RecordingRestartService(relayClient: relayClient);
    final failureReporter = FakeFailureReporter();
    final testChatHistory = createTestChatHistory();
    final composition = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      legacyMissingPluginId: plugin.id,
      pluginLifecycleService: lifecycleService,
      pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
      bridgeSettingsRepository: settingsRepositoryForLifecycleService(service: lifecycleService),
      clock: const ServerClock(),
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      attachmentSpillStorage: testChatHistory.spillStorage,
    archivedSessionStorage: testChatHistory.archivedStorage,
    archivedAttachmentStorage: testChatHistory.archivedSpillStorage,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: FakeTokenRefresher(),
      bridgeRegistrationService: registrationService,
      failureReporter: failureReporter,
      restartService: restartService,
      filesystemAccessOk: true,
      statusNotifier: null,
        reconnectBackoff: ReconnectBackoffPolicy.standard,
    ).create();
    final runtime = BridgeRuntime(
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      failureReporter: failureReporter,
      composition: composition,
    );
    final running = await startTestOrchestratorSession(session: composition.session);
    final socket = await relayServer.nextClient();
    final messages = StreamIterator<dynamic>(socket);
    expect(await messages.moveNext(), isTrue);
    expect(jsonDecodeMap(messages.current as String)["type"], "auth");

    return _ConcurrencyHarness._(
      plugin: plugin,
      composition: composition,
      runFuture: running.stopped,
      relayServer: relayServer,
      database: database,
      lifecycleService: lifecycleService,
      httpClient: httpClient,
      runtime: runtime,
      relayClient: relayClient,
      restartService: restartService,
      socket: socket,
      messages: messages,
    );
  }

  Future<void> insertSession({required String sessionId}) {
    return composition.sessionRepository.insertStoredSession(
      sessionId: sessionId,
      backendSessionId: "backend-$sessionId",
      pluginId: plugin.id,
      projectId: "/repo",
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      branchName: null,
      baseBranch: null,
      baseCommit: null,
      agent: null,
      agentModel: null,
    );
  }

  Future<SessionEncryptor> activatePhone({required int connId}) async {
    final crypto = RelayCryptoService();
    final phoneKeyPair = await crypto.generateKeyPair();
    final phonePublicKey = await phoneKeyPair.extractPublicKey();
    _sendPayload(
      connId: connId,
      payload: utf8.encode(
        jsonEncode(
          RelayMessage.keyExchange(
            publicKey: base64Url.encode(phonePublicKey.bytes).replaceAll("=", ""),
          ).toJson(),
        ),
      ),
    );

    final response = await _nextPayload(connId: connId);
    final bridgePublicKey = SimplePublicKey(response.sublist(0, 32), type: KeyPairType.x25519);
    final secret = await crypto.deriveSharedSecret(phoneKeyPair, peerPublicKey: bridgePublicKey);
    final keyExchangeEncryptor = crypto.createSessionEncryptor(await crypto.deriveEncryptionKey(secret));
    final readyBytes = await unframe(response.sublist(32), encryptor: keyExchangeEncryptor);
    final ready = RelayMessage.fromJson(jsonDecodeMap(utf8.decode(readyBytes))) as RelayReady;
    final roomKey = SecretKey(base64Url.decode(base64Url.normalize(ready.roomKey)));
    return crypto.createSessionEncryptor(roomKey);
  }

  void disconnectPhone({required int connId}) {
    _socket.add(jsonEncode({"type": "phone_disconnected", "connId": connId}));
  }

  Future<void> resumePhone({required int connId, required SessionEncryptor encryptor}) async {
    await sendEncrypted(
      connId: connId,
      encryptor: encryptor,
      message: const RelayMessage.resume(),
    );
    final response = await _nextPayload(connId: connId);
    final decrypted = await unframe(response, encryptor: encryptor);
    expect(
      RelayMessage.fromJson(jsonDecodeMap(utf8.decode(decrypted))),
      isA<RelayResumeAck>(),
    );
  }

  Future<void> sendEncrypted({
    required int connId,
    required SessionEncryptor encryptor,
    required RelayMessage message,
  }) async {
    final payload = await frame(
      utf8.encode(jsonEncode(message.toJson())),
      encryptor: encryptor,
    );
    _sendPayload(connId: connId, payload: payload);
  }

  Future<RelayResponse> nextResponse({
    required int connId,
    required SessionEncryptor encryptor,
    required String requestId,
  }) async {
    while (true) {
      final payload = await _nextPayload(connId: connId);
      final decrypted = await unframe(payload, encryptor: encryptor);
      final message = RelayMessage.fromJson(jsonDecodeMap(utf8.decode(decrypted)));
      if (message case final RelayResponse response when response.id == requestId) {
        return response;
      }
    }
  }

  Future<void> reconnectRelay() async {
    await _socket.close();
    await _messages.cancel();
    _socket = await relayServer.nextClient().timeout(const Duration(seconds: 5));
    _messages = StreamIterator<dynamic>(_socket);
    expect(await _messages.moveNext(), isTrue);
    expect(jsonDecodeMap(_messages.current as String)["type"], "auth");
  }

  void _sendPayload({required int connId, required List<int> payload}) {
    _socket.add(<int>[connId >> 8, connId & 0xFF, ...payload]);
  }

  Future<List<int>> _nextPayload({required int connId}) async {
    while (await _messages.moveNext().timeout(const Duration(seconds: 5))) {
      final message = _messages.current;
      if (message is! List<int> || message.length < 2) continue;
      final messageConnId = message[0] << 8 | message[1];
      if (messageConnId == connId) return message.sublist(2);
    }
    throw StateError("relay closed before a payload for connId $connId");
  }

  Future<void> close() async {
    await composition.session.cancel();
    await runFuture.timeout(const Duration(seconds: 10));
    await _messages.cancel();
    await runtime.close();
    await lifecycleService.dispose();
    httpClient.close();
    await plugin.closeEvents();
    await relayServer.close();
  }
}

class _BlockingMessagesPlugin extends FakeBridgePlugin {
  Completer<void>? messagesStarted;
  Future<void>? messagesDelay;

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    final started = messagesStarted;
    if (started != null && !started.isCompleted) started.complete();
    final delay = messagesDelay;
    if (delay != null) await delay;
    return super.getSessionMessages(sessionId);
  }
}

class _RecordingRelayClient extends RelayClient {
  _RecordingRelayClient({
    required super.relayURL,
    required super.accessTokenProvider,
    required super.bridgeIdProvider,
  });

  final List<({RelayConnection connection, int connId})> sendAttempts = [];
  final List<RelayConnection> closeAttempts = [];
  final Completer<void> closeStarted = Completer<void>();
  int sendCount = 0;
  bool failNextSend = false;
  Future<void>? closeDelay;

  @override
  RelaySendOutcome sendIfCurrent({
    required RelayConnection connection,
    required int connID,
    required List<int> payload,
  }) {
    sendAttempts.add((connection: connection, connId: connID));
    if (failNextSend) {
      failNextSend = false;
      throw StateError("send failed intentionally");
    }
    final outcome = super.sendIfCurrent(
      connection: connection,
      connID: connID,
      payload: payload,
    );
    if (outcome == RelaySendOutcome.sent) sendCount++;
    return outcome;
  }

  @override
  Future<RelayCloseOutcome> closeIfCurrent({required RelayConnection connection}) async {
    closeAttempts.add(connection);
    final closeFuture = super.closeIfCurrent(connection: connection);
    if (!closeStarted.isCompleted) closeStarted.complete();
    final delay = closeDelay;
    if (delay != null) await delay;
    return closeFuture;
  }
}

class _RecordingRestartService implements BridgeRestartService {
  _RecordingRestartService({required this.relayClient});

  final _RecordingRelayClient relayClient;
  final Completer<void> handoffPerformed = Completer<void>();
  bool restartable = false;
  Completer<void>? canRestartStarted;
  Future<void>? canRestartDelay;
  int handoffCalls = 0;
  int? sendCountAtHandoff;
  int? sendAttemptCountAtHandoff;
  int? closeAttemptCountAtHandoff;

  @override
  Future<bool> canRestart() async {
    final started = canRestartStarted;
    if (started != null && !started.isCompleted) started.complete();
    final delay = canRestartDelay;
    if (delay != null) await delay;
    return restartable;
  }

  @override
  Future<bool> canSpawnSuccessor() async => restartable;

  @override
  Future<bool> performRestartHandoff() async {
    handoffCalls++;
    sendCountAtHandoff = relayClient.sendCount;
    sendAttemptCountAtHandoff = relayClient.sendAttempts.length;
    closeAttemptCountAtHandoff = relayClient.closeAttempts.length;
    if (!handoffPerformed.isCompleted) handoffPerformed.complete();
    return true;
  }

  @override
  Future<bool> spawnSuccessor() async => true;
}
