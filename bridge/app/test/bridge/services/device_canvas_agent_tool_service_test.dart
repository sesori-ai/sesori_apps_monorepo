import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/device_canvas_agent_tool_service.dart";
import "package:sesori_bridge/src/services/device_canvas_claim_service.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("DeviceCanvasAgentToolService", () {
    late AppDatabase db;
    late DeviceCanvasIntegrationState integrationState;
    late DeviceCanvasClaimService claimService;
    late _BridgeIdProvider bridgeIdProvider;
    late String? currentBridgeId;
    late _SessionRepository sessionRepository;
    late DeviceCanvasAgentToolService service;

    setUp(() async {
      db = createTestDatabase();
      integrationState = DeviceCanvasIntegrationState()
        ..connect(canvasInstanceId: "canvas-1", protocolVersion: deviceCanvasIpcProtocolVersion)
        ..replaceInventory([_descriptor("ios:booted"), _descriptor("android:booted")]);
      claimService = DeviceCanvasClaimService(
        repository: DeviceCanvasClaimRepository(
          claimDao: db.deviceCanvasClaimDao,
          sessionDao: db.sessionDao,
          now: () => 1000,
        ),
        integrationState: integrationState,
      );
      await _insertSession(
        db: db,
        sessionId: "canonical-1",
        backendSessionId: "backend-1",
        projectId: "project-1",
      );
      await _insertSession(
        db: db,
        sessionId: "canonical-2",
        backendSessionId: "backend-2",
        projectId: "project-2",
      );
      currentBridgeId = "bridge-1";
      bridgeIdProvider = _BridgeIdProvider(() => currentBridgeId);
      sessionRepository = _SessionRepository({
        "opencode:backend-1": _session(
          sessionId: "canonical-1",
          backendSessionId: "backend-1",
          projectId: "project-1",
        ),
        "opencode:backend-2": _session(
          sessionId: "canonical-2",
          backendSessionId: "backend-2",
          projectId: "project-2",
        ),
      });
      service = DeviceCanvasAgentToolService(
        bridgeIdProvider: bridgeIdProvider,
        claimService: claimService,
        integrationState: integrationState,
        sessionRepository: sessionRepository,
      );
    });

    tearDown(() async {
      await claimService.dispose();
      await integrationState.dispose();
      await db.close();
    });

    test("binds claims and releases to the canonical invoking session", () async {
      final claimed = await service.claimSimulator(
        pluginId: "opencode",
        backendSessionId: "backend-1",
        deviceKey: "ios:booted",
      );
      final repeated = await service.claimSimulator(
        pluginId: "opencode",
        backendSessionId: "backend-1",
        deviceKey: "ios:booted",
      );
      final conflict = await service.claimSimulator(
        pluginId: "opencode",
        backendSessionId: "backend-2",
        deviceKey: "ios:booted",
      );

      expect(claimed, isA<DeviceCanvasAgentSimulatorClaimed>());
      expect(repeated, isA<DeviceCanvasAgentSimulatorAlreadyOwned>());
      expect(conflict, isA<DeviceCanvasAgentSimulatorConflict>());
      expect((await claimService.snapshot(bridgeId: "bridge-1")).single.sessionId, "canonical-1");

      final wrongOwner = await service.releaseSimulator(
        pluginId: "opencode",
        backendSessionId: "backend-2",
        deviceKey: "ios:booted",
      );
      final released = await service.releaseSimulator(
        pluginId: "opencode",
        backendSessionId: "backend-1",
        deviceKey: "ios:booted",
      );
      final repeatedRelease = await service.releaseSimulator(
        pluginId: "opencode",
        backendSessionId: "backend-1",
        deviceKey: "ios:booted",
      );

      expect(wrongOwner, isA<DeviceCanvasAgentSimulatorConflict>());
      expect(released, isA<DeviceCanvasAgentSimulatorReleased>());
      expect(repeatedRelease, isA<DeviceCanvasAgentSimulatorAlreadyReleased>());
    });

    test("lists bounded privacy-safe ownership relative to the caller", () async {
      await service.claimSimulator(
        pluginId: "opencode",
        backendSessionId: "backend-1",
        deviceKey: "ios:booted",
      );
      await service.claimSimulator(
        pluginId: "opencode",
        backendSessionId: "backend-2",
        deviceKey: "android:booted",
      );

      final result = await service.listSimulators(pluginId: "opencode", backendSessionId: "backend-1");

      expect(result, isA<DeviceCanvasAgentSimulatorsListed>());
      final listed = result as DeviceCanvasAgentSimulatorsListed;
      expect(listed.devices.map((device) => device.deviceKey), ["android:booted", "ios:booted"]);
      expect(listed.devices.first.ownership, DeviceCanvasAgentDeviceOwnership.anotherSession);
      expect(listed.devices.last.ownership, DeviceCanvasAgentDeviceOwnership.currentSession);
      expect(listed.truncated, isFalse);

      integrationState.replaceInventory([
        for (var index = 0; index < 130; index++)
          _descriptor(
            "device-${index.toString().padLeft(3, "0")}",
            displayName: List<String>.filled(257, "😀").join(),
          ),
      ]);
      final bounded = await service.listSimulators(
        pluginId: "opencode",
        backendSessionId: "backend-1",
      ) as DeviceCanvasAgentSimulatorsListed;
      expect(bounded.devices, hasLength(128));
      expect(bounded.truncated, isTrue);
      expect(bounded.devices.first.displayName.runes, hasLength(256));
    });

    test("rejects missing, foreign, archived, tombstoned, and caller-named canonical sessions", () async {
      sessionRepository.sessions["opencode:archived"] = _session(
        sessionId: "canonical-1",
        backendSessionId: "archived",
        projectId: "project-1",
        archivedAt: 10,
      );
      sessionRepository.sessions["opencode:tombstoned"] = _session(
        sessionId: "canonical-2",
        backendSessionId: "tombstoned",
        projectId: "project-2",
      );
      sessionRepository.tombstonedSessionIds.add("canonical-2");

      for (final invocation in <(String, String)>[
        ("opencode", "missing"),
        ("codex", "backend-1"),
        ("opencode", "canonical-1"),
        ("opencode", "archived"),
        ("opencode", "tombstoned"),
      ]) {
        expect(
          await service.claimSimulator(
            pluginId: invocation.$1,
            backendSessionId: invocation.$2,
            deviceKey: "ios:booted",
          ),
          isA<DeviceCanvasAgentSessionUnavailable>(),
        );
      }
      expect(await claimService.snapshot(bridgeId: "bridge-1"), isEmpty);
    });

    test("hard-disables tools when disconnected and removes late old-bridge mutations", () async {
      integrationState.disconnect();
      expect(
        await service.listSimulators(pluginId: "opencode", backendSessionId: "backend-1"),
        isA<DeviceCanvasAgentIntegrationUnavailable>(),
      );
      expect(
        await service.claimSimulator(
          pluginId: "opencode",
          backendSessionId: "backend-1",
          deviceKey: "ios:booted",
        ),
        isA<DeviceCanvasAgentIntegrationUnavailable>(),
      );

      integrationState
        ..connect(canvasInstanceId: "canvas-2", protocolVersion: deviceCanvasIpcProtocolVersion)
        ..replaceInventory([_descriptor("ios:booted")]);
      final subscription = claimService.changes.listen((_) => currentBridgeId = "bridge-2");
      addTearDown(subscription.cancel);

      expect(
        await service.claimSimulator(
          pluginId: "opencode",
          backendSessionId: "backend-1",
          deviceKey: "ios:booted",
        ),
        isA<DeviceCanvasAgentBridgeUnavailable>(),
      );
      expect(await claimService.snapshot(bridgeId: "bridge-1"), isEmpty);
    });
  });
}

class const _BridgeIdProvider(final String? Function() _readBridgeId) implements BridgeIdProvider {
  @override
  String? get bridgeId => _readBridgeId();
}

class _SessionRepository(final Map<String, StoredSession> sessions) implements SessionRepository {
  final Set<String> tombstonedSessionIds = <String>{};

  @override
  Future<StoredSession?> getStoredSessionByBackendId({
    required String pluginId,
    required String backendSessionId,
  }) async {
    return sessions["$pluginId:$backendSessionId"];
  }

  @override
  Future<bool> isSessionTombstoned({required String sessionId}) async {
    return tombstonedSessionIds.contains(sessionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError("Unexpected call: ${invocation.memberName}");
}

StoredSession _session({
  required String sessionId,
  required String backendSessionId,
  required String projectId,
  int? archivedAt,
}) {
  return StoredSession(
    id: sessionId,
    backendSessionId: backendSessionId,
    pluginId: "opencode",
    projectId: projectId,
    parentSessionId: null,
    directory: "/tmp/$projectId",
    worktreePath: null,
    branchName: null,
    isDedicated: false,
    archivedAt: archivedAt,
    baseBranch: null,
    baseCommit: null,
  );
}

DeviceCanvasDescriptor _descriptor(String deviceKey, {String? displayName}) {
  return DeviceCanvasDescriptor(
    deviceKey: deviceKey,
    platform: DeviceCanvasPlatform.ios,
    displayName: displayName ?? deviceKey,
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
}

Future<void> _insertSession({
  required AppDatabase db,
  required String sessionId,
  required String backendSessionId,
  required String projectId,
}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  await db.sessionDao.insertSession(
    pluginId: "opencode",
    sessionId: sessionId,
    backendSessionId: backendSessionId,
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
