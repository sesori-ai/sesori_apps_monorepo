import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/bridge/device_canvas/rendezvous_repository.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/relay_client.dart";
import "package:sesori_bridge/src/models/bridge_config.dart";
import "package:sesori_bridge/src/orchestrator.dart";
import "package:sesori_bridge/src/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/server/services/bridge_restart_service.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
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

    test("connected Canvas stream signaling follows the encrypted claim lifecycle end to end", () async {
      final stderrBuffer = BufferingStdout();
      final previousLogLevel = Log.level;
      try {
        Log.level = LogLevel.verbose;
        await IOOverrides.runZoned(
          () async {
            _ConcurrencyHarness? harness;
            try {
              harness = await _ConcurrencyHarness.start();
              await harness.insertSession(sessionId: _canvasSessionId);
              final canvas = await harness.startCanvas();

              final claimAttempt = await harness.composition.deviceCanvasClaimService.claim(
                bridgeId: _canvasBridgeId,
                deviceKey: _canvasDeviceKey,
                sessionId: _canvasSessionId,
              );
              expect(claimAttempt, isA<DeviceCanvasClaimed>());
              final claimRevision = (claimAttempt as DeviceCanvasClaimed).claim.claimRevision;
              final phone = await harness.activatePhone(connId: 71);

              final tamperedRequest = DeviceCanvasStreamStartRequest(
                expectedBridgeId: _canvasBridgeId,
                sessionId: _canvasSessionId,
                deviceKey: _canvasDeviceKey,
                expectedClaimRevision: claimRevision,
                operationId: "tampered-operation",
                control: true,
                offer: _canvasOffer.copyWith(fingerprint: _canvasAnswerFingerprint),
                iceCandidates: const [_canvasOfferCandidate],
              );
              expect(tamperedRequest.isValid, isFalse);
              await harness.sendEncrypted(
                connId: 71,
                encryptor: phone,
                message: RelayMessage.request(
                  id: "tampered-stream-start",
                  method: "POST",
                  path: "/device-canvas/stream/start",
                  headers: const {},
                  body: jsonEncode(tamperedRequest.toJson()),
                ),
              );
              final tamperedResponse = await harness.nextResponse(
                connId: 71,
                encryptor: phone,
                requestId: "tampered-stream-start",
              );
              expect(tamperedResponse.id, "tampered-stream-start");
              expect(tamperedResponse.status, HttpStatus.badRequest);
              await canvas.expectNoMessage<DeviceCanvasStreamStartMessage>(const Duration(milliseconds: 100));

              final startRequest = DeviceCanvasStreamStartRequest(
                expectedBridgeId: _canvasBridgeId,
                sessionId: _canvasSessionId,
                deviceKey: _canvasDeviceKey,
                expectedClaimRevision: claimRevision,
                operationId: "operation-1",
                control: true,
                offer: _canvasOffer,
                iceCandidates: const [_canvasOfferCandidate],
              );
              expect(startRequest.isValid, isTrue);
              expect(utf8.encode(startRequest.offer.sdp), hasLength(lessThanOrEqualTo(maxDeviceCanvasRtcSdpBytes)));
              final relayStart = RelayMessage.request(
                id: "valid-stream-start",
                method: "POST",
                path: "/device-canvas/stream/start",
                headers: const {},
                body: jsonEncode(startRequest.toJson()),
              );
              expect(relayStart, isA<RelayRequest>(), reason: "signaling must use the generic request variant");
              await harness.sendEncrypted(connId: 71, encryptor: phone, message: relayStart);

              final streamStart = await canvas.nextMessage<DeviceCanvasStreamStartMessage>();
              expect(streamStart.bridgeId, _canvasBridgeId);
              expect(streamStart.sessionId, _canvasSessionId);
              expect(streamStart.deviceKey, _canvasDeviceKey);
              expect(streamStart.claimRevision, claimRevision);
              expect(streamStart.control, isTrue);
              expect(streamStart.offer, _canvasOffer);
              expect(streamStart.offer.fingerprint, _canvasOfferFingerprint);
              expect(streamStart.iceCandidates, const [_canvasOfferCandidate]);
              expect(streamStart.toJson().keys, isNot(contains("media")));

              canvas.send(
                DeviceCanvasInboundMessage.streamStarted(
                  requestId: streamStart.requestId,
                  leaseId: streamStart.leaseId,
                  answer: _canvasAnswer,
                  iceCandidates: const [_canvasAnswerCandidate],
                ),
              );

              final relayResponse = await harness.nextResponse(
                connId: 71,
                encryptor: phone,
                requestId: "valid-stream-start",
              );
              expect(relayResponse.id, "valid-stream-start");
              expect(relayResponse.status, HttpStatus.ok);
              final started = DeviceCanvasStreamStartResponse.fromJson(jsonDecodeMap(relayResponse.body!));
              expect(started.isValid, isTrue);
              expect(started.outcome, DeviceCanvasStreamStartOutcome.started);
              expect(started.leaseId, streamStart.leaseId);
              expect(started.answer, _canvasAnswer);
              expect(started.answer?.fingerprint, _canvasAnswerFingerprint);
              expect(started.iceCandidates, const [_canvasAnswerCandidate]);

              await _expectDatabaseDoesNotContain(harness.database, _canvasOffer.sdp);
              await _expectDatabaseDoesNotContain(harness.database, _canvasAnswer.sdp);
              expect(
                await harness.database.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: _canvasBridgeId),
                hasLength(1),
              );

              final release = await harness.composition.deviceCanvasClaimService.release(
                bridgeId: _canvasBridgeId,
                deviceKey: _canvasDeviceKey,
                sessionId: _canvasSessionId,
                expectedClaimRevision: claimRevision,
              );
              expect(release, isA<DeviceCanvasReleased>());
              final revoke = await canvas.nextMessage<DeviceCanvasStreamRevokeMessage>(
                where: (message) => message.leaseId == streamStart.leaseId,
              );
              expect(revoke.reason, DeviceCanvasStreamRevokeReason.claimChanged);

              final statusRequest = DeviceCanvasStreamStatusRequest(
                expectedBridgeId: _canvasBridgeId,
                sessionId: _canvasSessionId,
                deviceKey: _canvasDeviceKey,
                expectedClaimRevision: claimRevision,
                operationId: "operation-1",
              );
              await harness.sendEncrypted(
                connId: 71,
                encryptor: phone,
                message: RelayMessage.request(
                  id: "status-after-release",
                  method: "POST",
                  path: "/device-canvas/stream/status",
                  headers: const {},
                  body: jsonEncode(statusRequest.toJson()),
                ),
              );
              final statusRelayResponse = await harness.nextResponse(
                connId: 71,
                encryptor: phone,
                requestId: "status-after-release",
              );
              expect(statusRelayResponse.id, "status-after-release");
              expect(statusRelayResponse.status, HttpStatus.ok);
              final status = DeviceCanvasStreamStatusResponse.fromJson(jsonDecodeMap(statusRelayResponse.body!));
              expect(status.isValid, isTrue);
              expect(status.outcome, DeviceCanvasStreamStatusOutcome.unauthorized);
              expect(
                await harness.database.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: _canvasBridgeId),
                isEmpty,
              );
            } finally {
              await harness?.close();
            }
          },
          stderr: () => stderrBuffer,
        );
        expect(stderrBuffer.text, isNot(contains(_canvasOffer.sdp)), reason: "offer SDP must not be logged");
        expect(stderrBuffer.text, isNot(contains(_canvasAnswer.sdp)), reason: "answer SDP must not be logged");
      } finally {
        Log.level = previousLogLevel;
      }
    });
  });
}

const String _canvasBridgeId = "br_test1234";
const String _canvasSessionId = "connected-canvas-session";
const String _canvasDeviceKey = "android:emulator-5554";
const String _canvasOfferFingerprint =
    "sha-256 AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA";
const String _canvasAnswerFingerprint =
    "sha-256 BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB:BB";
const DeviceCanvasRtcDescription _canvasOffer = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.offer,
  sdp:
      "v=0\r\n"
      "o=- 1 1 IN IP4 127.0.0.1\r\n"
      "s=-\r\n"
      "t=0 0\r\n"
      "m=video 9 UDP/TLS/RTP/SAVPF 96\r\n"
      "c=IN IP4 0.0.0.0\r\n"
      "a=ice-ufrag:offerufrag\r\n"
      "a=ice-pwd:offerpassword123456789012\r\n"
      "a=fingerprint:$_canvasOfferFingerprint\r\n"
      "a=setup:actpass\r\n"
      "a=mid:0\r\n"
      "a=rtcp-mux\r\n"
      "a=recvonly\r\n"
      "a=rtpmap:96 H264/90000\r\n",
  fingerprint: _canvasOfferFingerprint,
);
const DeviceCanvasRtcDescription _canvasAnswer = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.answer,
  sdp:
      "v=0\r\n"
      "o=- 2 2 IN IP4 127.0.0.1\r\n"
      "s=-\r\n"
      "t=0 0\r\n"
      "m=video 9 UDP/TLS/RTP/SAVPF 96\r\n"
      "c=IN IP4 0.0.0.0\r\n"
      "a=ice-ufrag:answerufrag\r\n"
      "a=ice-pwd:answerpassword1234567890\r\n"
      "a=fingerprint:$_canvasAnswerFingerprint\r\n"
      "a=setup:active\r\n"
      "a=mid:0\r\n"
      "a=rtcp-mux\r\n"
      "a=sendonly\r\n"
      "a=rtpmap:96 H264/90000\r\n",
  fingerprint: _canvasAnswerFingerprint,
);
const DeviceCanvasIceCandidate _canvasOfferCandidate = DeviceCanvasIceCandidate(
  candidate: "candidate:1 1 udp 2122260223 127.0.0.1 50000 typ host",
  sdpMid: "0",
  sdpMLineIndex: 0,
);
const DeviceCanvasIceCandidate _canvasAnswerCandidate = DeviceCanvasIceCandidate(
  candidate: "candidate:2 1 udp 2122260223 127.0.0.1 50001 typ host",
  sdpMid: "0",
  sdpMLineIndex: 0,
);
const DeviceCanvasDescriptor _canvasAndroidDescriptor = DeviceCanvasDescriptor(
  deviceKey: _canvasDeviceKey,
  platform: DeviceCanvasPlatform.android,
  displayName: "Pixel 9",
  runtimeDescription: "Android 16",
  modelDescription: "Android SDK emulator",
  dimensions: DeviceCanvasDimensions(width: 412, height: 915),
  orientation: DeviceCanvasOrientation.portrait,
  capabilities: DeviceCanvasCapabilities(
    localView: true,
    remoteVideo: true,
    remoteControl: true,
    input: true,
  ),
);

Future<void> _expectDatabaseDoesNotContain(AppDatabase database, String sensitiveValue) async {
  final tables = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  for (final table in tables) {
    final tableName = table.read<String>("name");
    final rows = await database.customSelect('SELECT * FROM "$tableName"').get();
    expect(
      rows.expand((row) => row.data.values).whereType<String>().join("\n"),
      isNot(contains(sensitiveValue)),
      reason: "stream signaling must not be persisted in $tableName",
    );
  }
}

class _ConcurrencyHarness._({
  required final _BlockingMessagesPlugin plugin,
  required final OrchestratorComposition composition,
  required final Future<void> runFuture,
  required final TestRelayServer relayServer,
  required final AppDatabase database,
  required final PluginLifecycleService lifecycleService,
  required final http.Client httpClient,
  required final BridgeRuntime runtime,
  required final _RecordingRelayClient relayClient,
  required final _RecordingRestartService restartService,
  required var WebSocket _socket,
  required var StreamIterator<dynamic> _messages,
}) {
  Directory? _deviceCanvasDataDirectory;
  _CanvasPeer? _canvasPeer;

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

  Future<_CanvasPeer> startCanvas() async {
    final dataDirectory = await Directory.systemTemp.createTemp("connected-device-canvas-test-");
    _deviceCanvasDataDirectory = dataDirectory;
    await runtime.startDeviceCanvasIpcServer(
      dataDirectory: dataDirectory.path,
      bridgeId: _canvasBridgeId,
      processGeneration: "test-process-generation",
      bridgeRegistrations: const Stream<String>.empty(),
    );
    final rendezvous = await DeviceCanvasRendezvousRepository(dataDirectory: dataDirectory.path).read();
    if (rendezvous == null) throw StateError("Device Canvas IPC rendezvous was not written");
    expect(rendezvous.bridgeId, _canvasBridgeId);
    expect(rendezvous.protocolVersion, deviceCanvasIpcProtocolVersion);
    final socket = await WebSocket.connect(
      "ws://127.0.0.1:${rendezvous.port}",
      headers: {HttpHeaders.authorizationHeader: "Bearer ${rendezvous.bearerSecret}"},
    );
    final peer = _CanvasPeer(socket);
    _canvasPeer = peer;
    peer.send(
      const DeviceCanvasInboundMessage.hello(
        protocolVersion: deviceCanvasIpcProtocolVersion,
        canvasInstanceId: "connected-test-canvas",
        capabilities: DeviceCanvasCapabilities(
          localView: true,
          remoteVideo: true,
          remoteControl: true,
          input: true,
        ),
      ),
    );
    final accepted = await peer.nextMessage<DeviceCanvasHelloAccepted>();
    expect(accepted.bridgeId, _canvasBridgeId);
    await peer.nextMessage<DeviceCanvasClaimsSnapshot>();

    final inventoryPublished = composition.deviceCanvasIntegrationState.presenceChanges.firstWhere(
      (snapshot) => snapshot.devicesByKey.containsKey(_canvasDeviceKey),
    );
    peer.send(const DeviceCanvasInboundMessage.inventorySnapshot(devices: [_canvasAndroidDescriptor]));
    await inventoryPublished.timeout(const Duration(seconds: 5));
    return peer;
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
    try {
      await _canvasPeer?.close();
      _canvasPeer = null;
      await composition.session.cancel();
      await runFuture.timeout(const Duration(seconds: 10));
      await _messages.cancel();
      await runtime.close();
      await lifecycleService.dispose();
      httpClient.close();
      await plugin.closeEvents();
      await relayServer.close();
    } finally {
      final dataDirectory = _deviceCanvasDataDirectory;
      _deviceCanvasDataDirectory = null;
      if (dataDirectory != null && dataDirectory.existsSync()) {
        dataDirectory.deleteSync(recursive: true);
      }
    }
  }
}

class _CanvasPeer(final WebSocket _socket) {
  this {
    _subscription = _socket.listen((data) {
      if (data is! String) return;
      _messages.add(DeviceCanvasOutboundMessage.fromJson(jsonDecodeMap(data)));
      _arrivals.add(null);
    });
  }

  final List<DeviceCanvasOutboundMessage> _messages = <DeviceCanvasOutboundMessage>[];
  final StreamController<void> _arrivals = StreamController<void>.broadcast();
  late final StreamSubscription<dynamic> _subscription;

  void send(DeviceCanvasInboundMessage message) {
    _socket.add(jsonEncode(message.toJson()));
  }

  Future<T> nextMessage<T extends DeviceCanvasOutboundMessage>({bool Function(T message)? where}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      while (_messages.isNotEmpty) {
        final message = _messages.removeAt(0);
        if (message is T && (where == null || where(message))) return message;
      }
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) throw TimeoutException("No matching Device Canvas IPC message for $T");
      await _arrivals.stream.first.timeout(remaining);
    }
  }

  Future<void> expectNoMessage<T extends DeviceCanvasOutboundMessage>(Duration duration) async {
    await Future<void>.delayed(duration);
    final unexpected = _messages.whereType<T>().toList(growable: false);
    expect(unexpected, isEmpty, reason: "unexpected Device Canvas IPC message of type $T");
  }

  Future<void> close() async {
    await _socket.close();
    await _subscription.cancel();
    await _arrivals.close();
  }
}

class _BlockingMessagesPlugin() extends FakeBridgePlugin {
  Completer<void>? messagesStarted;
  Future<void>? messagesDelay;

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    final started = messagesStarted;
    if (started != null && !started.isCompleted) started.complete();
    final delay = messagesDelay;
    if (delay != null) await delay;
    return await super.getSessionMessages(sessionId);
  }
}

class _RecordingRelayClient({
  required super.relayURL,
  required super.accessTokenProvider,
  required super.bridgeIdProvider,
}) extends RelayClient {
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
    required Uint8List payload,
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
    return await closeFuture;
  }
}

class _RecordingRestartService({required final _RecordingRelayClient relayClient}) implements BridgeRestartService {
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
