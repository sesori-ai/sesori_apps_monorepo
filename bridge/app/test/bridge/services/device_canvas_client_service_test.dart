import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/device_canvas_claim_service.dart";
import "package:sesori_bridge/src/services/device_canvas_client_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("DeviceCanvasClientService", () {
    late AppDatabase db;
    late DeviceCanvasIntegrationState integrationState;
    late DeviceCanvasClaimService claimService;
    late DeviceCanvasClientService service;
    var now = 1000;

    setUp(() async {
      db = createTestDatabase();
      integrationState = DeviceCanvasIntegrationState()
        ..connect(canvasInstanceId: "canvas-1", protocolVersion: deviceCanvasIpcProtocolVersion)
        ..replaceInventory([_descriptor("ios:booted"), _descriptor("android:booted")]);
      claimService = DeviceCanvasClaimService(
        repository: DeviceCanvasClaimRepository(
          claimDao: db.deviceCanvasClaimDao,
          sessionDao: db.sessionDao,
          now: () => now,
        ),
        integrationState: integrationState,
      );
      await _insertSession(db: db, sessionId: "session-1", projectId: "project-1");
      await _insertSession(db: db, sessionId: "session-2", projectId: "project-2");
      service = DeviceCanvasClientService(
        bridgeIdProvider: const _BridgeIdProvider("bridge-1"),
        claimService: claimService,
        integrationState: integrationState,
        sessionRepository: const _SessionRepository({
          "session-1": "project-1",
          "session-2": "project-2",
        }),
      );
    });

    tearDown(() async {
      await integrationState.dispose();
      await db.close();
    });

    test("projects connection, presence, and ownership independently", () async {
      await claimService.claim(bridgeId: "bridge-1", deviceKey: "ios:booted", sessionId: "session-1");
      await claimService.claim(bridgeId: "bridge-1", deviceKey: "android:booted", sessionId: "session-2");

      final connected = await service.status(sessionId: "session-1");

      expect(connected.bridgeId, "bridge-1");
      expect(connected.projectId, "project-1");
      expect(connected.sessionAvailable, isTrue);
      expect(connected.connection, DeviceCanvasClientConnectionStatus.connected);
      expect(connected.devices, hasLength(2));
      expect(connected.devices.first.deviceKey, "ios:booted");
      expect(connected.devices.first.descriptor?.displayName, "ios:booted");
      expect(connected.devices.first.claim?.sessionId, "session-1");
      expect(connected.devices.last.claim?.sessionId, "session-2");

      integrationState.disconnect();
      final disconnected = await service.status(sessionId: "session-1");
      expect(disconnected.connection, DeviceCanvasClientConnectionStatus.disconnected);
      expect(disconnected.devices.where((device) => device.claim != null), hasLength(2));
    });

    test("claim, conflict, authenticated reassignment, and owner-scoped release", () async {
      final claimed = await service.claim(
        request: const DeviceCanvasClaimRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "ios:booted",
          expectedOwnerSessionId: null,
          expectedClaimRevision: null,
        ),
      );
      expect(claimed.outcome, DeviceCanvasMutationOutcome.claimed);
      expect(claimed.status.devices.first.claim?.revision, 1);

      final conflict = await service.claim(
        request: const DeviceCanvasClaimRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-2",
          deviceKey: "ios:booted",
          expectedOwnerSessionId: null,
          expectedClaimRevision: null,
        ),
      );
      expect(conflict.outcome, DeviceCanvasMutationOutcome.conflict);
      expect(
        conflict.status.devices.singleWhere((device) => device.deviceKey == "ios:booted").claim?.sessionId,
        "session-1",
      );

      now++;
      final reassigned = await service.claim(
        request: const DeviceCanvasClaimRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-2",
          deviceKey: "ios:booted",
          reassign: true,
          expectedOwnerSessionId: "session-1",
          expectedClaimRevision: 1,
        ),
      );
      expect(reassigned.outcome, DeviceCanvasMutationOutcome.reassigned);
      expect(reassigned.status.devices.first.claim?.sessionId, "session-2");
      expect(reassigned.status.devices.first.claim?.revision, 2);

      final wrongOwner = await service.release(
        request: const DeviceCanvasReleaseRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "ios:booted",
          expectedClaimRevision: 2,
        ),
      );
      expect(wrongOwner.outcome, DeviceCanvasMutationOutcome.conflict);

      final released = await service.release(
        request: const DeviceCanvasReleaseRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-2",
          deviceKey: "ios:booted",
          expectedClaimRevision: 2,
        ),
      );
      expect(released.outcome, DeviceCanvasMutationOutcome.released);
      expect(released.status.devices.first.claim, isNull);
    });

    test("rejects stale reassignment and release revisions", () async {
      await service.claim(
        request: const DeviceCanvasClaimRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "ios:booted",
          expectedOwnerSessionId: null,
          expectedClaimRevision: null,
        ),
      );
      now++;
      await claimService.reassign(
        bridgeId: "bridge-1",
        deviceKey: "ios:booted",
        sessionId: "session-2",
        expectedOwnerSessionId: "session-1",
        expectedClaimRevision: 1,
      );

      final staleReassignment = await service.claim(
        request: const DeviceCanvasClaimRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-2",
          deviceKey: "ios:booted",
          reassign: true,
          expectedOwnerSessionId: "session-1",
          expectedClaimRevision: 1,
        ),
      );
      expect(staleReassignment.outcome, DeviceCanvasMutationOutcome.conflict);

      final staleRelease = await service.release(
        request: const DeviceCanvasReleaseRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-2",
          deviceKey: "ios:booted",
          expectedClaimRevision: 1,
        ),
      );
      expect(staleRelease.outcome, DeviceCanvasMutationOutcome.conflict);
      expect(staleRelease.status.devices.first.claim?.revision, 2);
    });

    test("reports an absent claim as already released", () async {
      final released = await service.release(
        request: const DeviceCanvasReleaseRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "ios:booted",
          expectedClaimRevision: 1,
        ),
      );

      expect(released.outcome, DeviceCanvasMutationOutcome.alreadyReleased);
      expect(released.status.devices.first.claim, isNull);
    });

    test("rejects mutations scoped to a different bridge", () async {
      await expectLater(
        service.claim(
          request: const DeviceCanvasClaimRequest(
            expectedBridgeId: "bridge-2",
            sessionId: "session-1",
            deviceKey: "ios:booted",
            expectedOwnerSessionId: null,
            expectedClaimRevision: null,
          ),
        ),
        throwsA(isA<DeviceCanvasClientBridgeUnavailable>()),
      );
      await expectLater(
        service.release(
          request: const DeviceCanvasReleaseRequest(
            expectedBridgeId: "bridge-2",
            sessionId: "session-1",
            deviceKey: "ios:booted",
            expectedClaimRevision: 1,
          ),
        ),
        throwsA(isA<DeviceCanvasClientBridgeUnavailable>()),
      );

      expect(await claimService.snapshot(bridgeId: "bridge-1"), isEmpty);
    });

    test("removes a mutation that completes after bridge identity changes", () async {
      String? bridgeId = "bridge-1";
      final provider = _CallbackBridgeIdProvider(() => bridgeId);
      final guardedService = DeviceCanvasClientService(
        bridgeIdProvider: provider,
        claimService: claimService,
        integrationState: integrationState,
        sessionRepository: const _SessionRepository({
          "session-1": "project-1",
          "session-2": "project-2",
        }),
      );
      final subscription = claimService.changes.listen((_) => bridgeId = null);
      addTearDown(subscription.cancel);

      await expectLater(
        guardedService.claim(
          request: const DeviceCanvasClaimRequest(
            expectedBridgeId: "bridge-1",
            sessionId: "session-1",
            deviceKey: "ios:booted",
            expectedOwnerSessionId: null,
            expectedClaimRevision: null,
          ),
        ),
        throwsA(isA<DeviceCanvasClientBridgeUnavailable>()),
      );

      expect(await claimService.snapshot(bridgeId: "bridge-1"), isEmpty);
    });

    test("reports unavailable sessions and devices without changing claims", () async {
      final missingStatus = await service.status(sessionId: "missing");
      expect(missingStatus.sessionAvailable, isFalse);
      expect(missingStatus.projectId, isNull);

      final missingSession = await service.claim(
        request: const DeviceCanvasClaimRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "missing",
          deviceKey: "ios:booted",
          expectedOwnerSessionId: null,
          expectedClaimRevision: null,
        ),
      );
      expect(missingSession.outcome, DeviceCanvasMutationOutcome.sessionUnavailable);

      final missingDevice = await service.claim(
        request: const DeviceCanvasClaimRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "ios:missing",
          expectedOwnerSessionId: null,
          expectedClaimRevision: null,
        ),
      );
      expect(missingDevice.outcome, DeviceCanvasMutationOutcome.deviceUnavailable);
      expect(await claimService.snapshot(bridgeId: "bridge-1"), isEmpty);
    });

    test("bounds status inventory and reports truncation", () async {
      integrationState.replaceInventory([
        for (var index = 0; index < 130; index++) _descriptor("device-$index"),
      ]);

      final status = await service.status(sessionId: "session-1");

      expect(status.devices, hasLength(128));
      expect(status.inventoryTruncated, isTrue);
    });

    test("bounds persisted offline claims before projecting status", () async {
      for (var index = 0; index < 130; index++) {
        await db.deviceCanvasClaimDao.insertClaimIfAbsent(
          bridgeId: "bridge-1",
          deviceKey: "offline-${index.toString().padLeft(3, "0")}",
          sessionId: "session-1",
          claimRevision: 1,
          claimedAt: index,
          updatedAt: index,
        );
      }

      final status = await service.status(sessionId: "session-1");

      expect(status.devices, hasLength(128));
      expect(status.inventoryTruncated, isTrue);
      expect(status.devices.every((device) => device.claim?.sessionId == "session-1"), isTrue);
    });

    test("keeps a conflicting mutation target in a truncated response", () async {
      for (var index = 0; index < 128; index++) {
        await db.deviceCanvasClaimDao.insertClaimIfAbsent(
          bridgeId: "bridge-1",
          deviceKey: "owned-${index.toString().padLeft(3, "0")}",
          sessionId: "session-1",
          claimRevision: 1,
          claimedAt: index + 1,
          updatedAt: index + 1,
        );
      }
      await db.deviceCanvasClaimDao.insertClaimIfAbsent(
        bridgeId: "bridge-1",
        deviceKey: "ios:booted",
        sessionId: "session-2",
        claimRevision: 1,
        claimedAt: 1000,
        updatedAt: 1000,
      );

      final conflict = await service.claim(
        request: const DeviceCanvasClaimRequest(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "ios:booted",
          expectedOwnerSessionId: null,
          expectedClaimRevision: null,
        ),
      );

      expect(conflict.outcome, DeviceCanvasMutationOutcome.conflict);
      expect(conflict.status.inventoryTruncated, isTrue);
      expect(conflict.status.devices, hasLength(128));
      expect(conflict.status.devices.first.deviceKey, "ios:booted");
      expect(conflict.status.devices.first.claim?.sessionId, "session-2");
    });

    test("requires a registered bridge identity", () async {
      final unavailable = DeviceCanvasClientService(
        bridgeIdProvider: const _BridgeIdProvider(null),
        claimService: claimService,
        integrationState: integrationState,
        sessionRepository: const _SessionRepository({"session-1": "project-1"}),
      );

      expect(
        () => unavailable.status(sessionId: "session-1"),
        throwsA(isA<DeviceCanvasClientBridgeUnavailable>()),
      );
    });
  });
}

class const _BridgeIdProvider(@override final String? bridgeId) implements BridgeIdProvider;

class const _CallbackBridgeIdProvider(final String? Function() _readBridgeId) implements BridgeIdProvider {
  @override
  String? get bridgeId => _readBridgeId();
}

class const _SessionRepository(final Map<String, String> projectsBySessionId) implements SessionRepository {
  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async {
    final projectId = projectsBySessionId[sessionId];
    return projectId == null
        ? null
        : StoredSession(
            id: sessionId,
            backendSessionId: sessionId,
            pluginId: "opencode",
            projectId: projectId,
            parentSessionId: null,
            directory: "/tmp/$projectId",
            worktreePath: null,
            branchName: null,
            isDedicated: false,
            archivedAt: null,
            baseBranch: null,
            baseCommit: null,
          );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError("Unexpected call: ${invocation.memberName}");
}

DeviceCanvasDescriptor _descriptor(String deviceKey) => DeviceCanvasDescriptor(
  deviceKey: deviceKey,
  platform: DeviceCanvasPlatform.ios,
  displayName: deviceKey,
  runtimeDescription: "iOS 26",
  modelDescription: "iPhone",
  dimensions: const DeviceCanvasDimensions(width: 1179, height: 2556),
  orientation: DeviceCanvasOrientation.portrait,
  capabilities: const DeviceCanvasCapabilities(
    localView: true,
    remoteVideo: true,
    remoteControl: false,
    input: true,
  ),
);

Future<void> _insertSession({required AppDatabase db, required String sessionId, required String projectId}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  await db.sessionDao.insertSession(
    pluginId: "opencode",
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: projectId,
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
