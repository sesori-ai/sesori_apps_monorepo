import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart" as state;
import "package:sesori_bridge/src/bridge/device_canvas/ipc_server.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol_codec.dart";
import "package:sesori_bridge/src/bridge/device_canvas/rendezvous_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/bridge/services/device_canvas_claim_service.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("DeviceCanvasIpcServer", () {
    late Directory tempDir;
    late AppDatabase db;
    late state.DeviceCanvasIntegrationState integrationState;
    late DeviceCanvasClaimService claimService;
    late DeviceCanvasIpcServer server;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("device-canvas-ipc-test-");
      db = createTestDatabase();
      integrationState = state.DeviceCanvasIntegrationState();
      claimService = DeviceCanvasClaimService(
        repository: DeviceCanvasClaimRepository(
          claimDao: db.deviceCanvasClaimDao,
          sessionDao: db.sessionDao,
          now: () => 1000,
        ),
        integrationState: integrationState,
      );
      await _insertSession(db: db, sessionId: "session-1", title: "Demo Session");
      server = DeviceCanvasIpcServer(
        rendezvousRepository: DeviceCanvasRendezvousRepository(dataDirectory: tempDir.path),
        bridgeId: "bridge-a",
        processGeneration: "pid:generation",
        claimService: claimService,
        integrationState: integrationState,
        heartbeatTimeout: const Duration(milliseconds: 250),
      );
      await server.start();
    });

    tearDown(() async {
      await server.dispose();
      await claimService.dispose();
      await integrationState.dispose();
      await db.close();
      await tempDir.delete(recursive: true);
    });

    test("writes an authenticated loopback rendezvous file", () async {
      final rendezvous = jsonDecode(await File(server.rendezvousFilePath).readAsString()) as Map<String, dynamic>;

      expect(rendezvous["protocolVersion"], equals(deviceCanvasIpcProtocolVersion));
      expect(rendezvous["port"], equals(server.port));
      expect(rendezvous["bearerSecret"], isA<String>().having((value) => value.length, "length", greaterThan(40)));
      expect(rendezvous["bridgeId"], equals("bridge-a"));
      expect(rendezvous["processGeneration"], equals("pid:generation"));
    });

    test("rejects unauthenticated websocket upgrades before app messages", () async {
      await expectLater(
        WebSocket.connect("ws://127.0.0.1:${server.port}"),
        throwsA(isA<WebSocketException>()),
      );
    });

    test("accepts hello and publishes bounded claim snapshot and changes", () async {
      _makeDeviceAvailable(integrationState);
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "session-1");
      integrationState.disconnect();
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());

      socket.add(
        jsonEncode({
          "type": "hello",
          "protocolVersion": deviceCanvasIpcProtocolVersion,
          "canvasInstanceId": "canvas",
          "capabilities": _capabilitiesJson(),
        }),
      );

      expect(await _nextJson(messages), containsPair("type", "helloAccepted"));
      final snapshot = await _nextJson(messages);
      expect(snapshot["type"], equals("claimsSnapshot"));
      expect(snapshot["claims"], [
        allOf(
          containsPair("displayTitle", "Demo Session"),
          isNot(contains("projectId")),
        ),
      ]);
      expect(jsonEncode(snapshot), isNot(contains("/Users/dev/My App")));

      await claimService.release(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "session-1");
      final removed = await _nextJson(messages);
      expect(removed, containsPair("type", "claimRemoved"));
      expect(removed, containsPair("deviceKey", "ios:booted"));
    });

    test("bounds the initial claim snapshot", () async {
      for (var index = 0; index < 130; index++) {
        await db.deviceCanvasClaimDao.insertClaimIfAbsent(
          bridgeId: "bridge-a",
          deviceKey: "offline-${index.toString().padLeft(3, "0")}",
          sessionId: "session-1",
          claimRevision: 1,
          claimedAt: index + 1,
          updatedAt: index + 1,
        );
      }
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());

      socket.add(jsonEncode(_helloJson("canvas")));
      expect(await _nextJson(messages), containsPair("type", "helloAccepted"));
      final snapshot = await _nextJson(messages);

      expect(snapshot["type"], "claimsSnapshot");
      expect(snapshot["claims"], isA<List<dynamic>>().having((claims) => claims.length, "length", 128));
    });

    test("bounds projected display titles", () async {
      await db.sessionDao.setTitle(
        sessionId: "session-1",
        title: "".padRight(maxDeviceCanvasIpcDisplayLength + 1, "x"),
        updatedAt: 3,
        projectionUpdatedAt: 3,
      );
      _makeDeviceAvailable(integrationState);
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "session-1");
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());

      socket.add(jsonEncode(_helloJson("canvas")));
      await _nextJson(messages);
      final snapshot = await _nextJson(messages);
      final claims = snapshot["claims"] as List<dynamic>;
      final claim = claims.single as Map<String, dynamic>;

      expect((claim["displayTitle"] as String).length, maxDeviceCanvasIpcDisplayLength);
    });

    test("publishes inventory into integration state only after hello", () async {
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());
      socket.add(jsonEncode(_helloJson("canvas")));
      await _nextJson(messages);
      await _nextJson(messages);

      socket.add(
        jsonEncode({
          "type": "inventorySnapshot",
          "devices": [_descriptorJson("ios:booted")],
        }),
      );

      await expectLater(
        integrationState.presenceChanges,
        emits(
          predicate<state.DeviceCanvasPresenceSnapshot>((snapshot) => snapshot.devicesByKey.containsKey("ios:booted")),
        ),
      );
    });

    test("duplicate inventory keys fail closed at the server boundary", () async {
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());
      socket.add(jsonEncode(_helloJson("canvas")));
      await _nextJson(messages);
      await _nextJson(messages);

      socket.add(
        jsonEncode({
          "type": "inventorySnapshot",
          "devices": [_descriptorJson("ios:booted"), _descriptorJson("ios:booted")],
        }),
      );

      expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
      expect(integrationState.presenceSnapshot.devicesByKey, isEmpty);
    });

    test("inventory and heartbeat before hello fail closed", () async {
      final inventorySocket = await _connect(server);
      addTearDown(inventorySocket.close);
      final inventoryMessages = StreamIterator<String>(inventorySocket.cast<String>());
      inventorySocket.add(jsonEncode({"type": "inventorySnapshot", "devices": <Object?>[]}));
      expect(await inventoryMessages.moveNext().timeout(const Duration(seconds: 5)), isFalse);

      final heartbeatSocket = await _connect(server);
      addTearDown(heartbeatSocket.close);
      final heartbeatMessages = StreamIterator<String>(heartbeatSocket.cast<String>());
      heartbeatSocket.add(jsonEncode({"type": "heartbeat", "canvasInstanceId": "canvas", "observedAt": 1}));
      expect(await heartbeatMessages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
    });

    test("heartbeat identity mismatch clears connectivity and fails closed", () async {
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());
      socket.add(jsonEncode(_helloJson("canvas-a")));
      await _nextJson(messages);
      await _nextJson(messages);

      socket.add(jsonEncode({"type": "heartbeat", "canvasInstanceId": "canvas-b", "observedAt": 1}));

      expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
      expect(integrationState.isConnected, isFalse);
    });

    test("non-positive heartbeat observedAt fails closed", () async {
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());
      socket.add(jsonEncode(_helloJson("canvas")));
      await _nextJson(messages);
      await _nextJson(messages);

      socket.add(jsonEncode({"type": "heartbeat", "canvasInstanceId": "canvas", "observedAt": 0}));

      expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
    });

    test("buffers claim deltas while the initial snapshot is loading", () async {
      await server.dispose();
      final snapshotCompleter = Completer<List<DeviceCanvasClaimProjection>>();
      final controlledClaimService = _SnapshotControlledClaimService(
        delegate: claimService,
        snapshotFuture: snapshotCompleter.future,
      );
      server = DeviceCanvasIpcServer(
        rendezvousRepository: DeviceCanvasRendezvousRepository(dataDirectory: tempDir.path),
        bridgeId: "bridge-a",
        processGeneration: "pid:generation",
        claimService: controlledClaimService,
        integrationState: integrationState,
        heartbeatTimeout: const Duration(milliseconds: 250),
      );
      await server.start();
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());
      socket.add(jsonEncode(_helloJson("canvas-race")));

      expect(await _nextJson(messages), containsPair("type", "helloAccepted"));
      integrationState.replaceInventory([_descriptor("ios:booted")]);
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "session-1");
      snapshotCompleter.complete(const []);

      expect(await _nextJson(messages), containsPair("type", "claimsSnapshot"));
      final update = await _nextJson(messages);
      expect(update, containsPair("type", "claimUpdated"));
      expect(update["claim"], containsPair("deviceKey", "ios:booted"));
    });

    test("closes a peer when distinct pre-snapshot deltas exceed the bound", () async {
      await server.dispose();
      final snapshotCompleter = Completer<List<DeviceCanvasClaimProjection>>();
      final changes = StreamController<DeviceCanvasClaimChange>.broadcast(sync: true);
      addTearDown(changes.close);
      final controlledClaimService = _SnapshotControlledClaimService(
        delegate: claimService,
        snapshotFuture: snapshotCompleter.future,
        changeStream: changes.stream,
      );
      server = DeviceCanvasIpcServer(
        rendezvousRepository: DeviceCanvasRendezvousRepository(dataDirectory: tempDir.path),
        bridgeId: "bridge-a",
        processGeneration: "pid:generation",
        claimService: controlledClaimService,
        integrationState: integrationState,
        heartbeatTimeout: const Duration(seconds: 5),
      );
      await server.start();
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());
      socket.add(jsonEncode(_helloJson("canvas-overflow")));
      expect(await _nextJson(messages), containsPair("type", "helloAccepted"));

      for (var index = 0; index <= DeviceCanvasClaimRepository.maxProjectedClaims; index++) {
        changes.add(
          DeviceCanvasClaimRemoved(
            bridgeId: "bridge-a",
            deviceKey: "removed-$index",
            claimRevision: 1,
          ),
        );
      }

      expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
      expect(integrationState.isConnected, isFalse);
      snapshotCompleter.complete(const []);
    });

    test("replacement during snapshot loading installs the newer peer deterministically", () async {
      await server.dispose();
      final snapshotCompleter = Completer<List<DeviceCanvasClaimProjection>>();
      final controlledClaimService = _SnapshotControlledClaimService(
        delegate: claimService,
        snapshotFuture: snapshotCompleter.future,
      );
      server = DeviceCanvasIpcServer(
        rendezvousRepository: DeviceCanvasRendezvousRepository(dataDirectory: tempDir.path),
        bridgeId: "bridge-a",
        processGeneration: "pid:generation",
        claimService: controlledClaimService,
        integrationState: integrationState,
        heartbeatTimeout: const Duration(milliseconds: 250),
      );
      await server.start();
      final first = await _connect(server);
      addTearDown(first.close);
      final firstMessages = StreamIterator<String>(first.cast<String>());
      first.add(jsonEncode(_helloJson("canvas-old")));
      expect(await _nextJson(firstMessages), containsPair("type", "helloAccepted"));

      final second = await _connect(server);
      addTearDown(second.close);
      final secondMessages = StreamIterator<String>(second.cast<String>());
      expect(await firstMessages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
      snapshotCompleter.complete(const []);
      second.add(jsonEncode(_helloJson("canvas-new")));

      expect(await _nextJson(secondMessages), containsPair("type", "helloAccepted"));
      expect(await _nextJson(secondMessages), containsPair("type", "claimsSnapshot"));
      expect(
        integrationState.connectionSnapshot,
        isA<state.DeviceCanvasConnectedSnapshot>().having(
          (snapshot) => snapshot.canvasInstanceId,
          "canvasInstanceId",
          "canvas-new",
        ),
      );
    });

    test("snapshot load failure closes the peer and clears connectivity", () async {
      await server.dispose();
      final snapshotCompleter = Completer<List<DeviceCanvasClaimProjection>>();
      final failingClaimService = _SnapshotControlledClaimService(
        delegate: claimService,
        snapshotFuture: snapshotCompleter.future,
      );
      server = DeviceCanvasIpcServer(
        rendezvousRepository: DeviceCanvasRendezvousRepository(dataDirectory: tempDir.path),
        bridgeId: "bridge-a",
        processGeneration: "pid:generation",
        claimService: failingClaimService,
        integrationState: integrationState,
        heartbeatTimeout: const Duration(milliseconds: 250),
      );
      await server.start();
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());

      socket.add(jsonEncode(_helloJson("canvas")));

      expect(await _nextJson(messages), containsPair("type", "helloAccepted"));
      snapshotCompleter.completeError(StateError("snapshot failed"));
      expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
      expect(integrationState.isConnected, isFalse);
    });

    test("start failure cleans up the partial listener and rendezvous", () async {
      await server.dispose();
      final failingRepository = _FailingRendezvousRepository(dataDirectory: tempDir.path);
      server = DeviceCanvasIpcServer(
        rendezvousRepository: failingRepository,
        bridgeId: "bridge-a",
        processGeneration: "pid:generation",
        claimService: claimService,
        integrationState: integrationState,
        heartbeatTimeout: const Duration(milliseconds: 250),
      );

      await expectLater(server.start(), throwsStateError);

      expect(failingRepository.deleteCalled, isTrue);
      expect(integrationState.isConnected, isFalse);
      await expectLater(
        WebSocket.connect("ws://127.0.0.1:${failingRepository.createdPort}"),
        throwsA(anyOf(isA<WebSocketException>(), isA<SocketException>())),
      );
    });

    test("binary JSON frames are rejected without publishing inventory", () async {
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());
      socket.add(jsonEncode(_helloJson("canvas")));
      await _nextJson(messages);
      await _nextJson(messages);

      socket.add(
        utf8.encode(
          jsonEncode({
            "type": "inventorySnapshot",
            "devices": [_descriptorJson("ios:booted")],
          }),
        ),
      );

      expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
      expect(integrationState.presenceSnapshot.devicesByKey, isEmpty);
    });

    test("dispose attempts all cleanup steps before surfacing the first failure", () async {
      await server.dispose();
      final failingRepository = _DisposeFailingRendezvousRepository(dataDirectory: tempDir.path);
      final cancelFailingClaimService = _CancelFailingClaimService(delegate: claimService);
      server = DeviceCanvasIpcServer(
        rendezvousRepository: failingRepository,
        bridgeId: "bridge-a",
        processGeneration: "pid:generation",
        claimService: cancelFailingClaimService,
        integrationState: integrationState,
        heartbeatTimeout: const Duration(milliseconds: 250),
      );
      await server.start();
      final socket = await _connect(server);
      socket.add(jsonEncode(_helloJson("canvas")));
      final messages = StreamIterator<String>(socket.cast<String>());
      await _nextJson(messages);
      await _nextJson(messages);

      await expectLater(server.dispose(), throwsStateError);

      expect(failingRepository.deleteCalled, isTrue);
      expect(integrationState.isConnected, isFalse);
      expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
    });

    test("reconnect receives a full claims snapshot", () async {
      _makeDeviceAvailable(integrationState);
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "session-1");
      integrationState.disconnect();

      final first = await _connect(server);
      await first.close();
      final second = await _connect(server);
      addTearDown(second.close);
      final messages = StreamIterator<String>(second.cast<String>());
      second.add(jsonEncode(_helloJson("canvas-reconnect")));

      await _nextJson(messages);
      final snapshot = await _nextJson(messages);
      expect(snapshot["claims"], [containsPair("deviceKey", "ios:booted")]);
    });

    test("replacement peer closes the old peer without releasing claims", () async {
      _makeDeviceAvailable(integrationState);
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "session-1");
      integrationState.disconnect();
      final first = await _connect(server);
      addTearDown(first.close);
      final firstDone = Completer<void>();
      first.listen(null, onDone: firstDone.complete);

      final second = await _connect(server);
      addTearDown(second.close);

      await firstDone.future.timeout(const Duration(seconds: 5));
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), hasLength(1));
    });

    test("unknown protocol versions fail closed with compatibility status", () async {
      final socket = await _connect(server);
      addTearDown(socket.close);
      final messages = StreamIterator<String>(socket.cast<String>());

      socket.add(jsonEncode({..._helloJson("canvas"), "protocolVersion": 999}));

      final status = await _nextJson(messages);
      expect(status, containsPair("type", "compatibilityStatus"));
      expect(status, containsPair("supported", false));
      expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isFalse);
    });

    test("heartbeat timeout disconnects without releasing durable claims", () async {
      _makeDeviceAvailable(integrationState);
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "session-1");
      integrationState.disconnect();
      final socket = await _connect(server);
      addTearDown(socket.close);
      socket.add(jsonEncode(_helloJson("canvas")));
      final messages = StreamIterator<String>(socket.cast<String>());
      await _nextJson(messages);
      await _nextJson(messages);

      expect(await messages.moveNext().timeout(const Duration(seconds: 2)), isFalse);
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), hasLength(1));
    });
  });
}

Future<WebSocket> _connect(DeviceCanvasIpcServer server) async {
  final rendezvous = jsonDecode(await File(server.rendezvousFilePath).readAsString()) as Map<String, dynamic>;
  return await WebSocket.connect(
    "ws://127.0.0.1:${rendezvous["port"]}",
    headers: {HttpHeaders.authorizationHeader: "Bearer ${rendezvous["bearerSecret"]}"},
  );
}

Future<Map<String, dynamic>> _nextJson(StreamIterator<String> messages) async {
  expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isTrue);
  return jsonDecode(messages.current) as Map<String, dynamic>;
}

void _makeDeviceAvailable(state.DeviceCanvasIntegrationState integrationState) {
  integrationState.connect(canvasInstanceId: "claim-setup", protocolVersion: deviceCanvasIpcProtocolVersion);
  integrationState.replaceInventory(const [
    DeviceCanvasDescriptor(
      deviceKey: "ios:booted",
      platform: DeviceCanvasPlatform.ios,
      displayName: "iPhone",
      runtimeDescription: "iOS 18",
      modelDescription: "iPhone",
      dimensions: DeviceCanvasDimensions(width: 390, height: 844),
      orientation: DeviceCanvasOrientation.portrait,
      capabilities: DeviceCanvasCapabilities(
        localView: true,
        remoteVideo: true,
        remoteControl: true,
        input: true,
      ),
    ),
  ]);
}

DeviceCanvasDescriptor _descriptor(String deviceKey) {
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

Map<String, Object?> _capabilitiesJson() {
  return <String, Object?>{"localView": true, "remoteVideo": true, "remoteControl": true, "input": true};
}

Map<String, Object?> _helloJson(String canvasInstanceId) {
  return <String, Object?>{
    "type": "hello",
    "protocolVersion": deviceCanvasIpcProtocolVersion,
    "canvasInstanceId": canvasInstanceId,
    "capabilities": _capabilitiesJson(),
  };
}

Map<String, Object?> _descriptorJson(String deviceKey) {
  return <String, Object?>{
    "deviceKey": deviceKey,
    "platform": "ios",
    "displayName": "iPhone",
    "runtimeDescription": "iOS 18",
    "modelDescription": "iPhone",
    "dimensions": <String, Object?>{"width": 390, "height": 844},
    "orientation": "portrait",
    "capabilities": _capabilitiesJson(),
  };
}

Future<void> _insertSession({required AppDatabase db, required String sessionId, required String title}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: ["/Users/dev/My App"]);
  await db.sessionDao.insertSession(
    pluginId: "opencode",
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: "/Users/dev/My App",
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
  );
  await db.sessionDao.setTitle(sessionId: sessionId, title: title, updatedAt: 2, projectionUpdatedAt: 2);
}

class _FailingRendezvousRepository({@override required final String dataDirectory})
    implements DeviceCanvasRendezvousRepository {
  @override
  final String directoryPath = "$dataDirectory/failing-device-canvas";
  int? createdPort;
  bool deleteCalled = false;

  @override
  String get filePath => "$directoryPath/ipc-rendezvous.json";

  @override
  DeviceCanvasRendezvous create({
    required int port,
    required String bearerSecret,
    required String bridgeId,
    required String processGeneration,
  }) {
    createdPort = port;
    return DeviceCanvasRendezvous(
      protocolVersion: deviceCanvasIpcProtocolVersion,
      port: port,
      bearerSecret: bearerSecret,
      bridgeId: bridgeId,
      processGeneration: processGeneration,
    );
  }

  @override
  Future<void> delete() async {
    deleteCalled = true;
  }

  @override
  Future<DeviceCanvasRendezvous?> read() async => null;

  @override
  Future<void> write(DeviceCanvasRendezvous rendezvous) async {
    throw StateError("rendezvous write failed");
  }
}

class _DisposeFailingRendezvousRepository({required super.dataDirectory}) extends DeviceCanvasRendezvousRepository {
  bool deleteCalled = false;

  @override
  Future<void> delete() async {
    deleteCalled = true;
    throw StateError("rendezvous delete failed");
  }
}

class _SnapshotControlledClaimService({
  required final DeviceCanvasClaimService delegate,
  required final Future<List<DeviceCanvasClaimProjection>> snapshotFuture,
  final Stream<DeviceCanvasClaimChange>? changeStream,
}) implements DeviceCanvasClaimService {
  @override
  Stream<DeviceCanvasClaimChange> get changes => changeStream ?? delegate.changes;

  @override
  Future<List<DeviceCanvasClaimProjection>> snapshot({required String bridgeId}) => snapshotFuture;

  @override
  Future<DeviceCanvasClaimProjectionPage> clientSnapshot({
    required String bridgeId,
    required String sessionId,
    required Set<String> liveDeviceKeys,
    required String? priorityDeviceKey,
    required int limit,
  }) {
    return delegate.clientSnapshot(
      bridgeId: bridgeId,
      sessionId: sessionId,
      liveDeviceKeys: liveDeviceKeys,
      priorityDeviceKey: priorityDeviceKey,
      limit: limit,
    );
  }

  @override
  Future<List<DeviceCanvasClaimRemoved>> snapshotRemovalsForSessions({required List<String> sessionIds}) {
    return delegate.snapshotRemovalsForSessions(sessionIds: sessionIds);
  }

  @override
  void publishRemovals(List<DeviceCanvasClaimRemoved> removals) => delegate.publishRemovals(removals);

  @override
  Future<void> publishSessionClaimUpdates({required String sessionId}) {
    return delegate.publishSessionClaimUpdates(sessionId: sessionId);
  }

  @override
  Future<DeviceCanvasClaimAttempt> claim({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
  }) {
    return delegate.claim(bridgeId: bridgeId, deviceKey: deviceKey, sessionId: sessionId);
  }

  @override
  Future<DeviceCanvasClaimAttempt> reassign({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    required String expectedOwnerSessionId,
    required int expectedClaimRevision,
  }) {
    return delegate.reassign(
      bridgeId: bridgeId,
      deviceKey: deviceKey,
      sessionId: sessionId,
      expectedOwnerSessionId: expectedOwnerSessionId,
      expectedClaimRevision: expectedClaimRevision,
    );
  }

  @override
  Future<DeviceCanvasReleaseAttempt> release({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    int? expectedClaimRevision,
  }) {
    return delegate.release(
      bridgeId: bridgeId,
      deviceKey: deviceKey,
      sessionId: sessionId,
      expectedClaimRevision: expectedClaimRevision,
    );
  }

  @override
  Future<void> releaseSessionClaims({required String sessionId}) => delegate.releaseSessionClaims(sessionId: sessionId);

  @override
  Future<void> releaseSessionsClaims({required List<String> sessionIds}) {
    return delegate.releaseSessionsClaims(sessionIds: sessionIds);
  }

  @override
  Future<void> cleanupForStartup({required String bridgeId}) => delegate.cleanupForStartup(bridgeId: bridgeId);

  @override
  Future<void> cleanupBridgeIdentity({required String bridgeId}) => delegate.cleanupBridgeIdentity(bridgeId: bridgeId);

  @override
  Future<void> dispose() => Future<void>.value();
}

class _CancelFailingClaimService({required final DeviceCanvasClaimService delegate})
    implements DeviceCanvasClaimService {
  final StreamController<DeviceCanvasClaimChange> _controller = StreamController<DeviceCanvasClaimChange>(
    onCancel: () => throw StateError("claim stream cancel failed"),
  );

  @override
  Stream<DeviceCanvasClaimChange> get changes => _controller.stream;

  @override
  Future<List<DeviceCanvasClaimProjection>> snapshot({required String bridgeId}) =>
      delegate.snapshot(bridgeId: bridgeId);

  @override
  Future<DeviceCanvasClaimProjectionPage> clientSnapshot({
    required String bridgeId,
    required String sessionId,
    required Set<String> liveDeviceKeys,
    required String? priorityDeviceKey,
    required int limit,
  }) {
    return delegate.clientSnapshot(
      bridgeId: bridgeId,
      sessionId: sessionId,
      liveDeviceKeys: liveDeviceKeys,
      priorityDeviceKey: priorityDeviceKey,
      limit: limit,
    );
  }

  @override
  Future<List<DeviceCanvasClaimRemoved>> snapshotRemovalsForSessions({required List<String> sessionIds}) {
    return delegate.snapshotRemovalsForSessions(sessionIds: sessionIds);
  }

  @override
  void publishRemovals(List<DeviceCanvasClaimRemoved> removals) => delegate.publishRemovals(removals);

  @override
  Future<void> publishSessionClaimUpdates({required String sessionId}) {
    return delegate.publishSessionClaimUpdates(sessionId: sessionId);
  }

  @override
  Future<DeviceCanvasClaimAttempt> claim({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
  }) {
    return delegate.claim(bridgeId: bridgeId, deviceKey: deviceKey, sessionId: sessionId);
  }

  @override
  Future<DeviceCanvasClaimAttempt> reassign({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    required String expectedOwnerSessionId,
    required int expectedClaimRevision,
  }) {
    return delegate.reassign(
      bridgeId: bridgeId,
      deviceKey: deviceKey,
      sessionId: sessionId,
      expectedOwnerSessionId: expectedOwnerSessionId,
      expectedClaimRevision: expectedClaimRevision,
    );
  }

  @override
  Future<DeviceCanvasReleaseAttempt> release({
    required String bridgeId,
    required String deviceKey,
    required String sessionId,
    int? expectedClaimRevision,
  }) {
    return delegate.release(
      bridgeId: bridgeId,
      deviceKey: deviceKey,
      sessionId: sessionId,
      expectedClaimRevision: expectedClaimRevision,
    );
  }

  @override
  Future<void> releaseSessionClaims({required String sessionId}) => delegate.releaseSessionClaims(sessionId: sessionId);

  @override
  Future<void> releaseSessionsClaims({required List<String> sessionIds}) {
    return delegate.releaseSessionsClaims(sessionIds: sessionIds);
  }

  @override
  Future<void> cleanupForStartup({required String bridgeId}) => delegate.cleanupForStartup(bridgeId: bridgeId);

  @override
  Future<void> cleanupBridgeIdentity({required String bridgeId}) => delegate.cleanupBridgeIdentity(bridgeId: bridgeId);

  @override
  Future<void> dispose() => _controller.close();
}
