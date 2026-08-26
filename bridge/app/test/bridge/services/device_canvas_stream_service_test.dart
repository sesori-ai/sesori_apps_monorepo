import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/bridge/device_canvas/stream_gateway.dart";
import "package:sesori_bridge/src/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/routing/post_device_canvas_stream_start_handler.dart";
import "package:sesori_bridge/src/routing/post_device_canvas_stream_status_handler.dart";
import "package:sesori_bridge/src/routing/post_device_canvas_stream_stop_handler.dart";
import "package:sesori_bridge/src/routing/request_router.dart";
import "package:sesori_bridge/src/routing/routed_request.dart";
import "package:sesori_bridge/src/routing/routed_request_dispatcher.dart";
import "package:sesori_bridge/src/services/device_canvas_claim_service.dart";
import "package:sesori_bridge/src/services/device_canvas_stream_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show ServerClock;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  group("DeviceCanvasStreamService", () {
    test("starts through the real gateway, reports one controller, and does not persist signaling", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);

      final started = await fixture.startActive(client: fixture.firstClient);

      expect(started.response.outcome, DeviceCanvasStreamStartOutcome.started);
      expect(started.response.isValid, isTrue);
      expect(started.response.leaseId, started.command.leaseId);
      expect(started.response.expiresAt, started.command.expiresAt);
      expect(started.response.answer, _answer);
      expect(started.command.bridgeId, _bridgeId);
      expect(started.command.sessionId, _sessionId);
      expect(started.command.deviceKey, _deviceKey);
      expect(started.command.claimRevision, fixture.claimRevision);
      expect(started.command.control, isTrue);
      expect(started.command.offer, _offer);
      expect(started.command.turn, isNull);

      final status = await fixture.service.status(
        client: fixture.firstClient,
        request: fixture.statusRequest(),
      );
      expect(status.outcome, DeviceCanvasStreamStatusOutcome.active);
      expect(status.isValid, isTrue);
      expect(status.leaseId, started.command.leaseId);
      expect(status.answer, _answer);
      expect(status.offerFingerprint, _offerFingerprint);

      await _expectDatabaseDoesNotContain(fixture.db, _offer.sdp);
      await _expectDatabaseDoesNotContain(fixture.db, _answer.sdp);
      expect(await fixture.db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: _bridgeId), hasLength(1));
    });

    test("waits for an exact pending start before answering status", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final commandFuture = fixture.gateway.commands
          .where((command) => command is DeviceCanvasStreamStartMessage)
          .cast<DeviceCanvasStreamStartMessage>()
          .first;
      final startFuture = fixture.service.start(
        client: fixture.firstClient,
        request: fixture.startRequest(control: false),
      );
      final command = await commandFuture.timeout(const Duration(seconds: 1));
      final statusFuture = fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest());

      expect(
        (await fixture.service.status(client: fixture.secondClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.controllerConflict,
      );

      final statusReturnedEarly = await Future.any([
        statusFuture.then((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 20), () => false),
      ]);
      expect(statusReturnedEarly, isFalse);

      expect(
        fixture.gateway.resolveStarted(
          requestId: command.requestId,
          leaseId: command.leaseId,
          answer: _answer,
          iceCandidates: const [_iceCandidate],
        ),
        isTrue,
      );
      expect((await startFuture).outcome, DeviceCanvasStreamStartOutcome.started);
      final status = await statusFuture;
      expect(status.outcome, DeviceCanvasStreamStatusOutcome.active);
      expect(status.leaseId, command.leaseId);
      expect(status.offerFingerprint, _offerFingerprint);
    });

    test("a different operation cannot observe or revoke a pending start", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final commandFuture = fixture.gateway.commands
          .where((command) => command is DeviceCanvasStreamStartMessage)
          .cast<DeviceCanvasStreamStartMessage>()
          .first;
      final firstStart = fixture.service.start(
        client: fixture.firstClient,
        request: fixture.startRequest(control: false),
      );
      final command = await commandFuture.timeout(const Duration(seconds: 1));

      final secondStart = await fixture.service.start(
        client: fixture.firstClient,
        request: fixture.startRequest(operationId: _otherOperationId, control: false),
      );
      final secondStatus = await fixture.service.status(
        client: fixture.firstClient,
        request: fixture.statusRequest(operationId: _otherOperationId),
      );

      expect(secondStart.outcome, DeviceCanvasStreamStartOutcome.controllerConflict);
      expect(secondStatus.outcome, DeviceCanvasStreamStatusOutcome.controllerConflict);
      expect(fixture.streamStarts, hasLength(1));
      expect(fixture.streamRevokes, isEmpty);

      expect(
        fixture.gateway.resolveStarted(
          requestId: command.requestId,
          leaseId: command.leaseId,
          answer: _answer,
          iceCandidates: const [_iceCandidate],
        ),
        isTrue,
      );
      expect((await firstStart).outcome, DeviceCanvasStreamStartOutcome.started);
      expect(
        (await fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.active,
      );
    });

    test("bounds a pending start and cannot promote its late response", () async {
      final fixture = await _StreamFixture.create(startOperationTimeout: const Duration(milliseconds: 200));
      addTearDown(fixture.dispose);
      final commandFuture = fixture.gateway.commands
          .where((command) => command is DeviceCanvasStreamStartMessage)
          .cast<DeviceCanvasStreamStartMessage>()
          .first;
      final revokeFuture = fixture.nextRevoke();
      final startFuture = fixture.service.start(
        client: fixture.firstClient,
        request: fixture.startRequest(control: false),
      );
      final command = await commandFuture.timeout(const Duration(seconds: 1));

      expect((await startFuture).outcome, DeviceCanvasStreamStartOutcome.unavailable);
      final revoke = await revokeFuture;
      expect(revoke.leaseId, command.leaseId);
      expect(revoke.reason, DeviceCanvasStreamRevokeReason.startFailed);
      expect(
        fixture.gateway.resolveStarted(
          requestId: command.requestId,
          leaseId: command.leaseId,
          answer: _answer,
          iceCandidates: const [_iceCandidate],
        ),
        isTrue,
      );
      expect(
        (await fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.inactive,
      );
    });

    test("fences a second relay connection from the active controller lease", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final started = await fixture.startActive(client: fixture.firstClient);
      final startsBeforeConflict = fixture.streamStarts.length;

      final conflict = await fixture.service.start(
        client: fixture.secondClient,
        request: fixture.startRequest(),
      );
      final status = await fixture.service.status(
        client: fixture.secondClient,
        request: fixture.statusRequest(),
      );
      final stop = await fixture.service.stop(
        client: fixture.secondClient,
        request: fixture.stopRequest(leaseId: started.command.leaseId),
      );

      expect(conflict.outcome, DeviceCanvasStreamStartOutcome.controllerConflict);
      expect(status.outcome, DeviceCanvasStreamStatusOutcome.controllerConflict);
      expect(stop.outcome, DeviceCanvasStreamStopOutcome.unauthorized);
      expect(fixture.streamStarts, hasLength(startsBeforeConflict));
      expect(
        (await fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.active,
      );
    });

    test("rejects stale claims, wrong sessions, unavailable devices, and unsupported capabilities", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);

      expect(
        (await fixture.service.start(
          client: fixture.firstClient,
          request: fixture.startRequest(expectedClaimRevision: fixture.claimRevision + 1),
        )).outcome,
        DeviceCanvasStreamStartOutcome.unauthorized,
      );
      expect(
        (await fixture.service.start(
          client: fixture.firstClient,
          request: fixture.startRequest(sessionId: _otherSessionId),
        )).outcome,
        DeviceCanvasStreamStartOutcome.unauthorized,
      );

      final staleRevision = fixture.claimRevision;
      await fixture.claimService.release(
        bridgeId: _bridgeId,
        deviceKey: _deviceKey,
        sessionId: _sessionId,
        expectedClaimRevision: staleRevision,
      );
      final reclaimed = await fixture.claimService.claim(
        bridgeId: _bridgeId,
        deviceKey: _deviceKey,
        sessionId: _sessionId,
      ) as DeviceCanvasClaimed;
      fixture.claimRevision = reclaimed.claim.claimRevision;
      expect(
        (await fixture.service.start(
          client: fixture.firstClient,
          request: fixture.startRequest(expectedClaimRevision: staleRevision),
        )).outcome,
        DeviceCanvasStreamStartOutcome.unauthorized,
      );

      fixture.integrationState.disconnect();
      expect(
        (await fixture.service.start(client: fixture.firstClient, request: fixture.startRequest())).outcome,
        DeviceCanvasStreamStartOutcome.unavailable,
      );

      fixture.integrationState
        ..connect(canvasInstanceId: "canvas-2", protocolVersion: deviceCanvasIpcProtocolVersion)
        ..replaceInventory(const []);
      expect(
        (await fixture.service.start(client: fixture.firstClient, request: fixture.startRequest())).outcome,
        DeviceCanvasStreamStartOutcome.unavailable,
      );

      fixture.integrationState.replaceInventory([
        _androidDescriptor(
          capabilities: const DeviceCanvasCapabilities(
            localView: true,
            remoteVideo: false,
            remoteControl: true,
            input: true,
          ),
        ),
      ]);
      expect(
        (await fixture.service.start(client: fixture.firstClient, request: fixture.startRequest())).outcome,
        DeviceCanvasStreamStartOutcome.unsupported,
      );

      fixture.integrationState.replaceInventory([
        _androidDescriptor(
          capabilities: const DeviceCanvasCapabilities(
            localView: true,
            remoteVideo: true,
            remoteControl: false,
            input: true,
          ),
        ),
      ]);
      expect(
        (await fixture.service.start(client: fixture.firstClient, request: fixture.startRequest())).outcome,
        DeviceCanvasStreamStartOutcome.unsupported,
      );

      fixture.integrationState.replaceInventory([
        _androidDescriptor(
          capabilities: const DeviceCanvasCapabilities(
            localView: true,
            remoteVideo: true,
            remoteControl: true,
            input: false,
          ),
        ),
      ]);
      expect(
        (await fixture.service.start(client: fixture.firstClient, request: fixture.startRequest())).outcome,
        DeviceCanvasStreamStartOutcome.unsupported,
      );
      expect(fixture.streamStarts, isEmpty);
    });

    test("joins claim release lifecycle events for direct release and session archive release", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final first = await fixture.startActive(client: fixture.firstClient);
      final firstRevoke = fixture.nextRevoke();

      await fixture.claimService.release(
        bridgeId: _bridgeId,
        deviceKey: _deviceKey,
        sessionId: _sessionId,
        expectedClaimRevision: fixture.claimRevision,
      );

      expect(
        await firstRevoke,
        isA<DeviceCanvasStreamRevokeMessage>()
            .having((message) => message.leaseId, "leaseId", first.command.leaseId)
            .having((message) => message.reason, "reason", DeviceCanvasStreamRevokeReason.claimChanged),
      );
      expect(
        (await fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.unauthorized,
      );

      final reclaimed = await fixture.claimService.claim(
        bridgeId: _bridgeId,
        deviceKey: _deviceKey,
        sessionId: _sessionId,
      ) as DeviceCanvasClaimed;
      fixture.claimRevision = reclaimed.claim.claimRevision;
      final second = await fixture.startActive(client: fixture.firstClient);
      final archivePathRevoke = fixture.nextRevoke();

      await fixture.claimService.releaseSessionClaims(sessionId: _sessionId);

      expect(
        await archivePathRevoke,
        isA<DeviceCanvasStreamRevokeMessage>()
            .having((message) => message.leaseId, "leaseId", second.command.leaseId)
            .having((message) => message.reason, "reason", DeviceCanvasStreamRevokeReason.claimChanged),
      );
      expect(
        (await fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.unauthorized,
      );
    });

    test("revokes on the durable reassignment signal before a new owner starts", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final started = await fixture.startActive(client: fixture.firstClient, control: false);
      final revokeFuture = fixture.nextRevoke();

      final reassigned = await fixture.claimService.reassign(
        bridgeId: _bridgeId,
        deviceKey: _deviceKey,
        sessionId: _otherSessionId,
        expectedOwnerSessionId: _sessionId,
        expectedClaimRevision: fixture.claimRevision,
      ) as DeviceCanvasClaimReassigned;
      fixture.claimRevision = reassigned.claim.claimRevision;

      final revoke = await revokeFuture;
      expect(revoke.leaseId, started.command.leaseId);
      expect(revoke.reason, DeviceCanvasStreamRevokeReason.claimChanged);
      expect(
        (await fixture.service.status(
          client: fixture.firstClient,
          request: fixture.statusRequest(sessionId: _otherSessionId),
        )).outcome,
        DeviceCanvasStreamStatusOutcome.inactive,
      );
    });

    test("never exposes a stale lease after durable reassignment without a projection event", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final started = await fixture.startActive(client: fixture.firstClient, control: false);
      final revokeFuture = fixture.nextRevoke();

      final reassigned = await fixture.claimRepository.reassign(
        bridgeId: _bridgeId,
        deviceKey: _deviceKey,
        sessionId: _otherSessionId,
        expectedOwnerSessionId: _sessionId,
        expectedClaimRevision: fixture.claimRevision,
      ) as DeviceCanvasClaimReassigned;
      fixture.claimRevision = reassigned.claim.claimRevision;
      final status = await fixture.service.status(
        client: fixture.firstClient,
        request: fixture.statusRequest(sessionId: _otherSessionId),
      );

      expect(status.outcome, DeviceCanvasStreamStatusOutcome.inactive);
      expect(status.leaseId, isNull);
      expect(status.answer, isNull);
      expect(status.offerFingerprint, isNull);
      final revoke = await revokeFuture;
      expect(revoke.leaseId, started.command.leaseId);
      expect(revoke.reason, DeviceCanvasStreamRevokeReason.claimChanged);
    });

    test("a new owner cannot stop an old lease identity", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final started = await fixture.startActive(client: fixture.firstClient, control: false);
      final revokeFuture = fixture.nextRevoke();
      final reassigned = await fixture.claimRepository.reassign(
        bridgeId: _bridgeId,
        deviceKey: _deviceKey,
        sessionId: _otherSessionId,
        expectedOwnerSessionId: _sessionId,
        expectedClaimRevision: fixture.claimRevision,
      ) as DeviceCanvasClaimReassigned;
      fixture.claimRevision = reassigned.claim.claimRevision;

      final stop = await fixture.service.stop(
        client: fixture.firstClient,
        request: fixture.stopRequest(leaseId: started.command.leaseId, sessionId: _otherSessionId),
      );

      expect(stop.outcome, DeviceCanvasStreamStopOutcome.unauthorized);
      expect((await revokeFuture).reason, DeviceCanvasStreamRevokeReason.claimChanged);
    });

    test("revokes for connection and Canvas disconnects but not for Canvas stream closure", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final first = await fixture.startActive(client: fixture.firstClient);
      final connectionRevoke = fixture.nextRevoke();

      fixture.service.releaseConnection(connectionId: fixture.firstClient.connectionId);

      expect(
        await connectionRevoke,
        isA<DeviceCanvasStreamRevokeMessage>()
            .having((message) => message.leaseId, "leaseId", first.command.leaseId)
            .having((message) => message.reason, "reason", DeviceCanvasStreamRevokeReason.clientDisconnected),
      );
      expect(
        (await fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.unauthorized,
      );

      fixture.registerFirstConnection();
      final second = await fixture.startActive(client: fixture.firstClient);
      final canvasRevoke = fixture.nextRevoke();
      fixture.integrationState.disconnect();

      expect(
        await canvasRevoke,
        isA<DeviceCanvasStreamRevokeMessage>()
            .having((message) => message.leaseId, "leaseId", second.command.leaseId)
            .having((message) => message.reason, "reason", DeviceCanvasStreamRevokeReason.canvasDisconnected),
      );

      fixture.integrationState
        ..connect(canvasInstanceId: "canvas-3", protocolVersion: deviceCanvasIpcProtocolVersion)
        ..replaceInventory([_androidDescriptor()]);
      final third = await fixture.startActive(client: fixture.firstClient);
      final revokesBeforeClose = fixture.streamRevokes.length;

      fixture.gateway.handleClosed(leaseId: third.command.leaseId, reason: DeviceCanvasStreamCloseReason.stopped);

      expect(fixture.streamRevokes, hasLength(revokesBeforeClose));
      expect(
        (await fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.inactive,
      );
    });

    test("expires and revokes a lease within a bounded timeout", () async {
      final fixture = await _StreamFixture.create(leaseDuration: const Duration(milliseconds: 30));
      addTearDown(fixture.dispose);
      final revokeFuture = fixture.nextRevoke();
      final started = await fixture.startActive(client: fixture.firstClient);

      final revoke = await revokeFuture;

      expect(revoke.leaseId, started.command.leaseId);
      expect(revoke.reason, DeviceCanvasStreamRevokeReason.expired);
      expect(
        (await fixture.service.status(client: fixture.firstClient, request: fixture.statusRequest())).outcome,
        DeviceCanvasStreamStatusOutcome.inactive,
      );
    });

    test("revokes active leases when required capabilities are withdrawn", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final controlled = await fixture.startActive(client: fixture.firstClient);
      final controlRevoke = fixture.nextRevoke();

      fixture.integrationState.replaceInventory([
        _androidDescriptor(
          capabilities: const DeviceCanvasCapabilities(
            localView: true,
            remoteVideo: true,
            remoteControl: false,
            input: true,
          ),
        ),
      ]);

      expect(
        await controlRevoke,
        isA<DeviceCanvasStreamRevokeMessage>()
            .having((message) => message.leaseId, "leaseId", controlled.command.leaseId)
            .having((message) => message.reason, "reason", DeviceCanvasStreamRevokeReason.deviceUnavailable),
      );

      fixture.integrationState.replaceInventory([_androidDescriptor()]);
      final video = await fixture.startActive(client: fixture.firstClient, control: false);
      final videoRevoke = fixture.nextRevoke();
      fixture.integrationState.replaceInventory([
        _androidDescriptor(
          capabilities: const DeviceCanvasCapabilities(
            localView: true,
            remoteVideo: false,
            remoteControl: true,
            input: true,
          ),
        ),
      ]);

      expect(
        await videoRevoke,
        isA<DeviceCanvasStreamRevokeMessage>()
            .having((message) => message.leaseId, "leaseId", video.command.leaseId)
            .having((message) => message.reason, "reason", DeviceCanvasStreamRevokeReason.deviceUnavailable),
      );
    });

    test("claim release settles pending setup and accepts only its exact late response", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final commandFuture = fixture.gateway.commands
          .where((command) => command is DeviceCanvasStreamStartMessage)
          .cast<DeviceCanvasStreamStartMessage>()
          .first;
      final responseFuture = fixture.service.start(
        client: fixture.firstClient,
        request: fixture.startRequest(),
      );
      final command = await commandFuture.timeout(const Duration(seconds: 1));
      final revokeFuture = fixture.nextRevoke();

      await fixture.claimService.release(
        bridgeId: _bridgeId,
        deviceKey: _deviceKey,
        sessionId: _sessionId,
        expectedClaimRevision: fixture.claimRevision,
      );

      expect((await responseFuture).outcome, DeviceCanvasStreamStartOutcome.unauthorized);
      expect((await revokeFuture).reason, DeviceCanvasStreamRevokeReason.claimChanged);
      expect(
        fixture.gateway.resolveStarted(
          requestId: command.requestId,
          leaseId: command.leaseId,
          answer: _answer,
          iceCandidates: const [_iceCandidate],
        ),
        isTrue,
      );
      expect(
        fixture.gateway.resolveStarted(
          requestId: command.requestId,
          leaseId: "wrong-lease",
          answer: _answer,
          iceCandidates: const [_iceCandidate],
        ),
        isFalse,
      );
    });
  });

  group("Device Canvas stream handlers", () {
    test("require relay context, reject invalid bodies, and use unforgeable dispatcher context", () async {
      final fixture = await _StreamFixture.create();
      addTearDown(fixture.dispose);
      final dispatcher = RoutedRequestDispatcher(
        router: RequestRouter(
          handlers: [
            PostDeviceCanvasStreamStartHandler(service: fixture.service),
            PostDeviceCanvasStreamStatusHandler(service: fixture.service),
            PostDeviceCanvasStreamStopHandler(service: fixture.service),
          ],
        ),
      );

      final local = await _dispatch(
        dispatcher,
        makeRequest("POST", "/device-canvas/stream/status", body: jsonEncode(fixture.statusRequest())),
      );
      final invalid = await _dispatch(
        dispatcher,
        makeRequest("POST", "/device-canvas/stream/start", body: jsonEncode(const <String, Object?>{})),
        context: RelayRoutedRequestContext(
          connectionId: fixture.firstClient.connectionId,
          connectionIncarnation: fixture.firstClient.connectionIncarnation,
        ),
      );

      expect(local.status, 403);
      expect(invalid.status, 400);

      final forgedBody = fixture.startRequest().toJson()
        ..["connectionId"] = fixture.secondClient.connectionId
        ..["connectionIncarnation"] = "client-forged-incarnation";
      final startCommand = fixture.gateway.commands
          .where((command) => command is DeviceCanvasStreamStartMessage)
          .cast<DeviceCanvasStreamStartMessage>()
          .first;
      final startResponse = _dispatch(
        dispatcher,
        makeRequest("POST", "/device-canvas/stream/start", body: jsonEncode(forgedBody)),
        context: RelayRoutedRequestContext(
          connectionId: fixture.firstClient.connectionId,
          connectionIncarnation: fixture.firstClient.connectionIncarnation,
        ),
      );
      final command = await startCommand.timeout(const Duration(seconds: 1));
      expect(
        fixture.gateway.resolveStarted(
          requestId: command.requestId,
          leaseId: command.leaseId,
          answer: _answer,
          iceCandidates: const [_iceCandidate],
        ),
        isTrue,
      );
      final startedResponse = DeviceCanvasStreamStartResponse.fromJson(
        jsonDecode((await startResponse).body!) as Map<String, dynamic>,
      );
      expect(startedResponse.outcome, DeviceCanvasStreamStartOutcome.started);

      final activeResponse = DeviceCanvasStreamStatusResponse.fromJson(
        jsonDecode(
          (await _dispatch(
            dispatcher,
            makeRequest("POST", "/device-canvas/stream/status", body: jsonEncode(fixture.statusRequest())),
            context: RelayRoutedRequestContext(
              connectionId: fixture.firstClient.connectionId,
              connectionIncarnation: fixture.firstClient.connectionIncarnation,
            ),
          )).body!,
        ) as Map<String, dynamic>,
      );
      expect(activeResponse.outcome, DeviceCanvasStreamStatusOutcome.active);

      final stopResponse = DeviceCanvasStreamStopResponse.fromJson(
        jsonDecode(
          (await _dispatch(
            dispatcher,
            makeRequest(
              "POST",
              "/device-canvas/stream/stop",
              body: jsonEncode(fixture.stopRequest(leaseId: command.leaseId)),
            ),
            context: RelayRoutedRequestContext(
              connectionId: fixture.firstClient.connectionId,
              connectionIncarnation: fixture.firstClient.connectionIncarnation,
            ),
          )).body!,
        ) as Map<String, dynamic>,
      );
      expect(stopResponse.outcome, DeviceCanvasStreamStopOutcome.stopped);
      expect(fixture.streamRevokes.single.reason, DeviceCanvasStreamRevokeReason.stopped);
    });
  });
}

class _StreamFixture({
  required final AppDatabase db,
  required final DeviceCanvasIntegrationState integrationState,
  required final DeviceCanvasClaimRepository claimRepository,
  required final DeviceCanvasClaimService claimService,
  required final DeviceCanvasStreamGateway gateway,
  required final DeviceCanvasStreamService service,
  required var int claimRevision,
  required final DeviceCanvasStreamClient firstClient,
  required final DeviceCanvasStreamClient secondClient,
}) {
  late final StreamSubscription<DeviceCanvasOutboundMessage> _commandSubscription;
  final List<DeviceCanvasOutboundMessage> commands = <DeviceCanvasOutboundMessage>[];

  static Future<_StreamFixture> create({
    Duration leaseDuration = const Duration(minutes: 10),
    Duration startOperationTimeout = const Duration(seconds: 15),
  }) async {
    final db = createTestDatabase();
    final integrationState = DeviceCanvasIntegrationState()
      ..connect(canvasInstanceId: "canvas-1", protocolVersion: deviceCanvasIpcProtocolVersion)
      ..replaceInventory([_androidDescriptor()]);
    final claimRepository = DeviceCanvasClaimRepository(
      claimDao: db.deviceCanvasClaimDao,
      sessionDao: db.sessionDao,
      now: () => _now.millisecondsSinceEpoch,
    );
    final claimService = DeviceCanvasClaimService(
      repository: claimRepository,
      integrationState: integrationState,
    );
    final gateway = DeviceCanvasStreamGateway();
    await _insertSession(db: db, sessionId: _sessionId);
    await _insertSession(db: db, sessionId: _otherSessionId);
    final claimed = await claimService.claim(
      bridgeId: _bridgeId,
      deviceKey: _deviceKey,
      sessionId: _sessionId,
    ) as DeviceCanvasClaimed;
    final firstIncarnation = Object();
    final secondIncarnation = Object();
    final firstClient = DeviceCanvasStreamClient(connectionId: 101, connectionIncarnation: firstIncarnation);
    final secondClient = DeviceCanvasStreamClient(connectionId: 202, connectionIncarnation: secondIncarnation);
    final service =
        DeviceCanvasStreamService(
            bridgeIdProvider: const _BridgeIdProvider(),
            claimService: claimService,
            integrationState: integrationState,
            gateway: gateway,
            clock: const _FixedClock(),
            leaseDuration: leaseDuration,
            startOperationTimeout: startOperationTimeout,
          )
          ..registerConnection(connectionId: firstClient.connectionId, connectionIncarnation: firstIncarnation)
          ..registerConnection(connectionId: secondClient.connectionId, connectionIncarnation: secondIncarnation);
    final fixture = _StreamFixture(
      db: db,
      integrationState: integrationState,
      claimRepository: claimRepository,
      claimService: claimService,
      gateway: gateway,
      service: service,
      claimRevision: claimed.claim.claimRevision,
      firstClient: firstClient,
      secondClient: secondClient,
    );
    fixture._commandSubscription = gateway.commands.listen(fixture.commands.add);
    return fixture;
  }

  Iterable<DeviceCanvasStreamStartMessage> get streamStarts => commands.whereType<DeviceCanvasStreamStartMessage>();
  Iterable<DeviceCanvasStreamRevokeMessage> get streamRevokes => commands.whereType<DeviceCanvasStreamRevokeMessage>();

  DeviceCanvasStreamStartRequest startRequest({
    String sessionId = _sessionId,
    int? expectedClaimRevision,
    String operationId = _operationId,
    bool control = true,
  }) => DeviceCanvasStreamStartRequest(
    expectedBridgeId: _bridgeId,
    sessionId: sessionId,
    deviceKey: _deviceKey,
    expectedClaimRevision: expectedClaimRevision ?? claimRevision,
    operationId: operationId,
    control: control,
    offer: _offer,
    iceCandidates: const [_iceCandidate],
  );

  DeviceCanvasStreamStatusRequest statusRequest({
    String sessionId = _sessionId,
    String operationId = _operationId,
  }) => DeviceCanvasStreamStatusRequest(
    expectedBridgeId: _bridgeId,
    sessionId: sessionId,
    deviceKey: _deviceKey,
    expectedClaimRevision: claimRevision,
    operationId: operationId,
  );

  DeviceCanvasStreamStopRequest stopRequest({required String leaseId, String sessionId = _sessionId}) =>
      DeviceCanvasStreamStopRequest(
        expectedBridgeId: _bridgeId,
        sessionId: sessionId,
        deviceKey: _deviceKey,
        expectedClaimRevision: claimRevision,
        leaseId: leaseId,
      );

  Future<({DeviceCanvasStreamStartResponse response, DeviceCanvasStreamStartMessage command})> startActive({
    required DeviceCanvasStreamClient client,
    bool control = true,
  }) async {
    final commandFuture = gateway.commands
        .where((command) => command is DeviceCanvasStreamStartMessage)
        .cast<DeviceCanvasStreamStartMessage>()
        .first;
    final responseFuture = service.start(
      client: client,
      request: startRequest(control: control),
    );
    final command = await commandFuture.timeout(const Duration(seconds: 1));
    expect(
      gateway.resolveStarted(
        requestId: command.requestId,
        leaseId: command.leaseId,
        answer: _answer,
        iceCandidates: const [_iceCandidate],
      ),
      isTrue,
    );
    return (response: await responseFuture.timeout(const Duration(seconds: 1)), command: command);
  }

  Future<DeviceCanvasStreamRevokeMessage> nextRevoke() => gateway.commands
      .where((command) => command is DeviceCanvasStreamRevokeMessage)
      .cast<DeviceCanvasStreamRevokeMessage>()
      .first
      .timeout(const Duration(seconds: 1));

  void registerFirstConnection() {
    service.registerConnection(
      connectionId: firstClient.connectionId,
      connectionIncarnation: firstClient.connectionIncarnation,
    );
  }

  Future<void> dispose() async {
    await service.dispose();
    await _commandSubscription.cancel();
    await gateway.dispose();
    await claimService.dispose();
    await integrationState.dispose();
    await db.close();
  }
}

const String _bridgeId = "bridge-a";
const String _sessionId = "session-1";
const String _otherSessionId = "session-2";
const String _deviceKey = "android:emulator-5554";
const String _operationId = "operation-1";
const String _otherOperationId = "operation-2";
final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1000000, isUtc: true);
const String _offerFingerprint =
    "sha-256 00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:10:21:32:43:54:65:76:87:98:A9:BA:CB:DC:ED:FE:0F";
const String _answerFingerprint =
    "sha-256 FF:EE:DD:CC:BB:AA:99:88:77:66:55:44:33:22:11:00:0F:1E:2D:3C:4B:5A:69:78:87:96:A5:B4:C3:D2:E1:F0";
const DeviceCanvasRtcDescription _offer = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.offer,
  sdp: "v=0\r\na=fingerprint:$_offerFingerprint\r\na=recvonly\r\n",
  fingerprint: _offerFingerprint,
);
const DeviceCanvasRtcDescription _answer = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.answer,
  sdp: "v=0\r\na=fingerprint:$_answerFingerprint\r\na=sendonly\r\n",
  fingerprint: _answerFingerprint,
);
const DeviceCanvasIceCandidate _iceCandidate = DeviceCanvasIceCandidate(
  candidate: "candidate:1 1 udp 1 127.0.0.1 9 typ host",
  sdpMid: "0",
  sdpMLineIndex: 0,
);

DeviceCanvasDescriptor _androidDescriptor({
  DeviceCanvasCapabilities capabilities = const DeviceCanvasCapabilities(
    localView: true,
    remoteVideo: true,
    remoteControl: true,
    input: true,
  ),
}) => DeviceCanvasDescriptor(
  deviceKey: _deviceKey,
  platform: DeviceCanvasPlatform.android,
  displayName: "Pixel 9",
  runtimeDescription: "Android 16",
  modelDescription: "Android SDK emulator",
  dimensions: const DeviceCanvasDimensions(width: 412, height: 915),
  orientation: DeviceCanvasOrientation.portrait,
  capabilities: capabilities,
);

Future<void> _insertSession({required AppDatabase db, required String sessionId}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: const ["/repo"]);
  await db.sessionDao.insertSession(
    pluginId: "opencode",
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: "/repo",
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
    preservePullRequestScope: false,
  );
}

Future<void> _expectDatabaseDoesNotContain(AppDatabase db, String sensitiveValue) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  for (final table in tables) {
    final tableName = table.read<String>("name");
    final rows = await db.customSelect('SELECT * FROM "$tableName"').get();
    expect(
      rows.expand((row) => row.data.values).whereType<String>().join("\n"),
      isNot(contains(sensitiveValue)),
      reason: "signaling material must not be persisted in $tableName",
    );
  }
}

Future<RelayResponse> _dispatch(
  RoutedRequestDispatcher dispatcher,
  RelayRequest request, {
  RoutedRequestContext context = const LocalRoutedRequestContext(),
}) async {
  final result = dispatcher.dispatch(request: request, context: context);
  expect(result, isA<RoutedRequestAccepted>());
  return (await (result as RoutedRequestAccepted).pendingRequest.completion).response;
}

class const _BridgeIdProvider() implements BridgeIdProvider {
  @override
  String get bridgeId => _bridgeId;
}

class const _FixedClock() implements ServerClock {
  @override
  Future<void> delay({required Duration duration}) => Future<void>.delayed(duration);

  @override
  DateTime now() => _now;
}
