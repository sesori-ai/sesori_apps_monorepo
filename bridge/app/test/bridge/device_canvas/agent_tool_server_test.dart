import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/bridge/device_canvas/agent_tool_rendezvous_repository.dart";
import "package:sesori_bridge/src/bridge/device_canvas/agent_tool_server.dart";
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
  group("DeviceCanvasAgentToolServer", () {
    const bootstrapSecret = "bootstrap-secret";
    late Directory tempDirectory;
    late String rendezvousPath;
    late AppDatabase db;
    late DeviceCanvasIntegrationState integrationState;
    late DeviceCanvasClaimService claimService;
    late DeviceCanvasAgentToolServer server;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp("device-canvas-agent-tools-");
      rendezvousPath = path.join(tempDirectory.path, deviceCanvasAgentToolRendezvousFileName);
      db = createTestDatabase();
      integrationState = DeviceCanvasIntegrationState()
        ..connect(canvasInstanceId: "canvas-1", protocolVersion: deviceCanvasIpcProtocolVersion)
        ..replaceInventory([_descriptor("ios:booted")]);
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
      final service = DeviceCanvasAgentToolService(
        bridgeIdProvider: const _BridgeIdProvider("bridge-1"),
        claimService: claimService,
        integrationState: integrationState,
        sessionRepository: _SessionRepository({
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
        }),
      );
      server = DeviceCanvasAgentToolServer(
        service: service,
        rendezvousRepository: DeviceCanvasAgentToolRendezvousRepository(filePath: rendezvousPath),
        pluginId: "opencode",
        bootstrapSecret: bootstrapSecret,
      );
      await server.start();
    });

    tearDown(() async {
      await server.dispose();
      await claimService.dispose();
      await integrationState.dispose();
      await db.close();
      if (tempDirectory.existsSync()) await tempDirectory.delete(recursive: true);
    });

    test("publishes an owner-only loopback rendezvous and rotates authenticated bearer tokens", () async {
      final rendezvous = jsonDecode(await File(rendezvousPath).readAsString()) as Map<String, dynamic>;
      expect(rendezvous, {
        "protocolVersion": 1,
        "port": server.boundPort,
      });
      if (!Platform.isWindows) {
        expect(FileStat.statSync(rendezvousPath).mode & 0x1ff, 0x180);
      }

      expect((await _request(server: server, route: "/register", token: "wrong")).statusCode, 401);
      final firstRegistration = await _request(server: server, route: "/register", token: bootstrapSecret);
      final firstToken = firstRegistration.body["bearerToken"] as String;
      expect(firstRegistration.statusCode, 200);
      expect(firstToken, hasLength(64));

      final secondRegistration = await _request(server: server, route: "/register", token: bootstrapSecret);
      final secondToken = secondRegistration.body["bearerToken"] as String;
      expect(secondToken, isNot(firstToken));
      expect(
        (await _request(
          server: server,
          route: "/list",
          token: firstToken,
          body: const {"backendSessionId": "backend-1"},
        )).statusCode,
        401,
      );
      expect(
        (await _request(
          server: server,
          route: "/list",
          token: secondToken,
          body: const {"backendSessionId": "backend-1"},
        )).body["outcome"],
        "listed",
      );
    });

    test("returns typed claim, conflict, idempotency, and owner-scoped release outcomes", () async {
      final token = await _register(server: server, bootstrapSecret: bootstrapSecret);

      expect(
        (await _mutation(server: server, token: token, route: "/claim", backendSessionId: "backend-1")).body,
        containsPair("outcome", "claimed"),
      );
      expect(
        (await _mutation(server: server, token: token, route: "/claim", backendSessionId: "backend-1")).body,
        containsPair("outcome", "alreadyOwned"),
      );
      expect(
        (await _mutation(server: server, token: token, route: "/claim", backendSessionId: "backend-2")).body,
        containsPair("outcome", "conflict"),
      );
      expect(
        (await _mutation(server: server, token: token, route: "/release", backendSessionId: "backend-2")).body,
        containsPair("outcome", "conflict"),
      );
      expect(
        (await _mutation(server: server, token: token, route: "/release", backendSessionId: "backend-1")).body,
        containsPair("outcome", "released"),
      );
      expect(
        (await _mutation(server: server, token: token, route: "/release", backendSessionId: "backend-1")).body,
        containsPair("outcome", "alreadyReleased"),
      );
    });

    test("rejects malformed, oversized, unknown, and non-POST requests and cleans up on shutdown", () async {
      final token = await _register(server: server, bootstrapSecret: bootstrapSecret);

      expect(
        (await _request(server: server, route: "/list", token: token, rawBody: "not-json")).statusCode,
        400,
      );
      expect(
        (await _request(
          server: server,
          route: "/list",
          token: token,
          rawBody: List<String>.filled(9000, "x").join(),
        )).statusCode,
        400,
      );
      expect((await _request(server: server, route: "/missing", token: token)).statusCode, 404);
      expect(
        (await _request(server: server, route: "/list", token: token, method: "GET")).statusCode,
        405,
      );

      await server.dispose();
      expect(File(rendezvousPath).existsSync(), isFalse);
    });
  });
}

Future<String> _register({required DeviceCanvasAgentToolServer server, required String bootstrapSecret}) async {
  final response = await _request(server: server, route: "/register", token: bootstrapSecret);
  return response.body["bearerToken"] as String;
}

Future<_HttpResponse> _mutation({
  required DeviceCanvasAgentToolServer server,
  required String token,
  required String route,
  required String backendSessionId,
}) {
  return _request(
    server: server,
    route: route,
    token: token,
    body: {"backendSessionId": backendSessionId, "deviceKey": "ios:booted"},
  );
}

Future<_HttpResponse> _request({
  required DeviceCanvasAgentToolServer server,
  required String route,
  required String token,
  String method = "POST",
  Map<String, Object?>? body,
  String? rawBody,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse("http://127.0.0.1:${server.boundPort}$route"),
    );
    request.headers.set(HttpHeaders.authorizationHeader, "Bearer $token");
    final encodedBody = rawBody ?? (body == null ? null : jsonEncode(body));
    if (encodedBody != null) {
      request.headers.contentType = ContentType.json;
      request.write(encodedBody);
    }
    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    return _HttpResponse(
      statusCode: response.statusCode,
      body: responseBody.isEmpty ? const <String, dynamic>{} : jsonDecode(responseBody) as Map<String, dynamic>,
    );
  } finally {
    client.close(force: true);
  }
}

class const _HttpResponse({required final int statusCode, required final Map<String, dynamic> body});

class const _BridgeIdProvider(@override final String? bridgeId) implements BridgeIdProvider;

class _SessionRepository(final Map<String, StoredSession> sessions) implements SessionRepository {
  @override
  Future<StoredSession?> getStoredSessionByBackendId({
    required String pluginId,
    required String backendSessionId,
  }) async {
    return sessions["$pluginId:$backendSessionId"];
  }

  @override
  Future<bool> isSessionTombstoned({required String sessionId}) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError("Unexpected call: ${invocation.memberName}");
}

StoredSession _session({required String sessionId, required String backendSessionId, required String projectId}) {
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
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
  );
}

DeviceCanvasDescriptor _descriptor(String deviceKey) {
  return DeviceCanvasDescriptor(
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
