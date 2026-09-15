import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/services/device_canvas_claim_service.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("DeviceCanvasClaimService", () {
    late AppDatabase db;
    late DeviceCanvasIntegrationState integrationState;
    late DeviceCanvasClaimService service;
    var now = 1000;

    setUp(() async {
      db = createTestDatabase();
      integrationState = DeviceCanvasIntegrationState();
      service = DeviceCanvasClaimService(
        repository: DeviceCanvasClaimRepository(
          claimDao: db.deviceCanvasClaimDao,
          sessionDao: db.sessionDao,
          now: () => now,
        ),
        integrationState: integrationState,
      );
      integrationState.connect(canvasInstanceId: "canvas-1", protocolVersion: deviceCanvasIpcProtocolVersion);
      integrationState.replaceInventory([_deviceDescriptor("ios:booted"), _deviceDescriptor("android:booted")]);
      await _insertSession(db: db, sessionId: "session-1");
      await _insertSession(db: db, sessionId: "session-2");
    });

    tearDown(() async {
      await service.dispose();
      await integrationState.dispose();
      await db.close();
    });

    test("claims an unowned bridge-scoped device and repeats as already owned", () async {
      final first = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      expect(first, isA<DeviceCanvasClaimed>());
      final claimed = (first as DeviceCanvasClaimed).claim;
      expect(claimed.claimRevision, equals(1));
      expect(claimed.claimedAt, equals(1000));
      expect(claimed.updatedAt, equals(1000));

      now = 1001;
      final second = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      expect(second, isA<DeviceCanvasClaimAlreadyOwned>());
      final alreadyOwned = (second as DeviceCanvasClaimAlreadyOwned).claim;
      expect(alreadyOwned.claimRevision, equals(1));
      expect(alreadyOwned.claimedAt, equals(1000));
      expect(alreadyOwned.updatedAt, equals(1001));
    });

    test("returns conflict without replacing another session claim", () async {
      await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      final result = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-2",
      );

      expect(result, isA<DeviceCanvasClaimConflict>());
      final conflict = (result as DeviceCanvasClaimConflict).claim;
      expect(conflict.sessionId, equals("session-1"));
    });

    test("authenticated human reassignment replaces the owner with a fenced revision", () async {
      await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      now = 1001;
      final committedFuture = service.committedClaims.first;
      var reassignmentCompleted = false;

      final resultFuture = service
          .reassign(
            bridgeId: "bridge-a",
            deviceKey: "ios:booted",
            sessionId: "session-2",
            expectedOwnerSessionId: "session-1",
            expectedClaimRevision: 1,
          )
          .whenComplete(() => reassignmentCompleted = true);
      final committed = await committedFuture;

      expect(committed.sessionId, "session-2");
      expect(committed.claimRevision, 2);
      expect(reassignmentCompleted, isFalse);
      final result = await resultFuture;

      expect(result, isA<DeviceCanvasClaimReassigned>());
      final reassigned = (result as DeviceCanvasClaimReassigned).claim;
      expect(reassigned.sessionId, "session-2");
      expect(reassigned.claimRevision, 2);
      expect(reassigned.claimedAt, 1001);
      final projection = (await service.snapshot(bridgeId: "bridge-a")).single;
      expect(projection.sessionId, "session-2");
      expect(projection.claimRevision, 2);
      expect(projection.claimedAt, 1001);
    });

    test("republishes a claimed session after its display title changes", () async {
      await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      await db.sessionDao.setTitle(
        sessionId: "session-1",
        title: "Renamed session",
        updatedAt: 1001,
        projectionUpdatedAt: 1001,
      );
      final update = service.changes
          .where((change) => change is DeviceCanvasClaimUpdated)
          .cast<DeviceCanvasClaimUpdated>()
          .first;

      await service.publishSessionClaimUpdates(sessionId: "session-1");

      expect((await update).projection.displayTitle, "Renamed session");
    });

    test("reassignment CAS rejects a stale claim revision", () async {
      await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      final replaced = await db.deviceCanvasClaimDao.replaceOwnedClaim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        expectedSessionId: "session-1",
        expectedClaimRevision: 0,
        sessionId: "session-2",
        claimRevision: 2,
        claimedAt: 1001,
        updatedAt: 1001,
      );

      expect(replaced, isFalse);
      final claim = await db.deviceCanvasClaimDao.getClaim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
      );
      expect(claim?.sessionId, "session-1");
      expect(claim?.claimRevision, 1);
    });

    test("keeps bridge identities isolated for the same device key", () async {
      final first = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      final second = await service.claim(
        bridgeId: "bridge-b",
        deviceKey: "ios:booted",
        sessionId: "session-2",
      );

      expect(first, isA<DeviceCanvasClaimed>());
      expect(second, isA<DeviceCanvasClaimed>());
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), hasLength(1));
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-b"), hasLength(1));
    });

    test("release is owner-scoped and idempotent", () async {
      await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      await service.release(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-2",
      );
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), hasLength(1));

      await service.release(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      await service.release(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), isEmpty);
    });

    test("release then reclaim increments revision during the same process", () async {
      final first = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      expect((first as DeviceCanvasClaimed).claim.claimRevision, equals(1));

      await service.release(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      final second = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-2",
      );
      expect((second as DeviceCanvasClaimed).claim.claimRevision, equals(2));
    });

    test("a durable high-water mark prevents released claim revision reuse after restart", () async {
      final first = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      ) as DeviceCanvasClaimed;
      await service.release(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
        expectedClaimRevision: first.claim.claimRevision,
      );
      final restarted = DeviceCanvasClaimService(
        repository: DeviceCanvasClaimRepository(
          claimDao: db.deviceCanvasClaimDao,
          sessionDao: db.sessionDao,
          now: () => now,
        ),
        integrationState: integrationState,
      );
      addTearDown(restarted.dispose);

      final reclaimed = await restarted.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      ) as DeviceCanvasClaimed;
      final staleRelease = await restarted.release(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
        expectedClaimRevision: first.claim.claimRevision,
      );

      expect(reclaimed.claim.claimRevision, 2);
      expect(staleRelease, isA<DeviceCanvasReleaseConflict>());
    });

    test("uses one monotonic revision counter per bridge", () async {
      final claims = await Future.wait([
        service.claim(
          bridgeId: "bridge-a",
          deviceKey: "ios:booted",
          sessionId: "session-1",
        ),
        service.claim(
          bridgeId: "bridge-a",
          deviceKey: "android:booted",
          sessionId: "session-2",
        ),
      ]);
      final bridgeBClaim = await service.claim(
        bridgeId: "bridge-b",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      ) as DeviceCanvasClaimed;

      expect(
        claims.map((attempt) => (attempt as DeviceCanvasClaimed).claim.claimRevision),
        unorderedEquals([1, 2]),
      );
      expect(bridgeBClaim.claim.claimRevision, 1);
      final counters = await db.select(db.deviceCanvasClaimRevisionsTable).get();
      expect(counters, hasLength(2));
      expect(
        {for (final counter in counters) counter.bridgeId: counter.lastRevision},
        {"bridge-a": 2, "bridge-b": 1},
      );
    });

    test("rejects new claims once the bounded projection is full", () async {
      for (var index = 0; index < DeviceCanvasClaimRepository.maxProjectedClaims; index++) {
        await db.deviceCanvasClaimDao.insertClaimIfAbsent(
          bridgeId: "bridge-a",
          deviceKey: "offline-${index.toString().padLeft(3, "0")}",
          sessionId: "session-1",
          claimRevision: 1,
          claimedAt: index + 1,
          updatedAt: index + 1,
        );
      }

      final result = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      expect(result, isA<DeviceCanvasClaimDeviceUnavailable>());
      expect(await db.deviceCanvasClaimDao.countClaimsForBridge(bridgeId: "bridge-a"), 128);
    });

    test("rejects absent and archived sessions", () async {
      final absent = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "missing",
      );
      expect(absent, isA<DeviceCanvasClaimSessionUnavailable>());

      await db.sessionDao.setArchived(
        sessionId: "session-1",
        archivedAt: 2000,
        updatedAt: 2000,
        projectionUpdatedAt: 2000,
      );
      final archived = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      expect(archived, isA<DeviceCanvasClaimSessionUnavailable>());
    });

    test("rejects tombstoned sessions", () async {
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "session-1",
        pluginId: "opencode",
        deletedAt: 2000,
      );

      final result = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      expect(result, isA<DeviceCanvasClaimSessionUnavailable>());
    });

    test("fresh claim rejects an absent device", () async {
      final result = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:missing",
        sessionId: "session-1",
      );

      expect(result, isA<DeviceCanvasClaimDeviceUnavailable>());
    });

    test("fresh claim rejects when Device Canvas is disconnected", () async {
      integrationState.disconnect();

      final result = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      expect(result, isA<DeviceCanvasClaimDeviceUnavailable>());
    });

    test("fresh claim rechecks device availability immediately before insertion", () async {
      var availabilityChecks = 0;
      final repository = DeviceCanvasClaimRepository(
        claimDao: db.deviceCanvasClaimDao,
        sessionDao: db.sessionDao,
        now: () => now,
      );

      final result = await repository.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
        canClaimUnownedDevice: () => ++availabilityChecks == 1,
      );

      expect(result, isA<DeviceCanvasClaimDeviceUnavailable>());
      expect(availabilityChecks, 2);
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), isEmpty);
    });

    test("same-owner repeat remains idempotent after the device goes offline", () async {
      final first = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      expect(first, isA<DeviceCanvasClaimed>());

      integrationState.replaceInventory(const []);
      final second = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );

      expect(second, isA<DeviceCanvasClaimAlreadyOwned>());
    });

    test("different-owner conflict is preserved after the device goes offline", () async {
      final first = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      expect(first, isA<DeviceCanvasClaimed>());

      integrationState.disconnect();
      final second = await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-2",
      );

      expect(second, isA<DeviceCanvasClaimConflict>());
      expect((second as DeviceCanvasClaimConflict).claim.sessionId, equals("session-1"));
    });

    test("session deletion cascades and cleanup removes stale identities", () async {
      await service.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "session-1",
      );
      await service.claim(
        bridgeId: "bridge-b",
        deviceKey: "android:booted",
        sessionId: "session-2",
      );

      await db.sessionDao.deleteSession(sessionId: "session-1");
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), isEmpty);

      await service.cleanupForStartup(bridgeId: "bridge-a");
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-b"), isEmpty);
    });
  });
}

DeviceCanvasDescriptor _deviceDescriptor(String deviceKey) {
  return DeviceCanvasDescriptor(
    deviceKey: deviceKey,
    platform: DeviceCanvasPlatform.ios,
    displayName: "iPhone",
    runtimeDescription: "iOS 18",
    modelDescription: "iPhone",
    dimensions: const DeviceCanvasDimensions(width: 390, height: 844),
    orientation: DeviceCanvasOrientation.portrait,
    capabilities: const DeviceCanvasCapabilities(localView: true, remoteVideo: true, remoteControl: true, input: true),
  );
}

Future<void> _insertSession({required AppDatabase db, required String sessionId}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
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
