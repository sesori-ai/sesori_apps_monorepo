import "dart:async";
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
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginAgentTool;
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

    test("binds MCP capabilities to one session without model-supplied identity", () async {
      final tools = server.pluginHost(pluginId: "opencode");
      final first = await tools.provisionMcp(backendSessionId: "backend-1");
      final second = await tools.provisionMcp(backendSessionId: "backend-2");

      final listed = await _mcpCall(server: server, token: first.bearerToken, name: "list_simulators");
      expect(listed.body["result"], containsPair("isError", false));
      expect(
        (listed.body["result"] as Map<String, dynamic>)["structuredContent"],
        containsPair("outcome", "listed"),
      );

      expect(
        ((await _mcpCall(
              server: server,
              token: first.bearerToken,
              name: "claim_simulator",
              arguments: const {"deviceKey": "ios:booted"},
            )).body["result"]
            as Map<String, dynamic>)["structuredContent"],
        containsPair("outcome", "claimed"),
      );
      expect(
        ((await _mcpCall(
              server: server,
              token: second.bearerToken,
              name: "claim_simulator",
              arguments: const {"deviceKey": "ios:booted"},
            )).body["result"]
            as Map<String, dynamic>)["structuredContent"],
        containsPair("outcome", "conflict"),
      );
      expect(
        ((await _mcpCall(
              server: server,
              token: first.bearerToken,
              name: "claim_simulator",
              arguments: const {"backendSessionId": "backend-2", "deviceKey": "ios:booted"},
            )).body["result"]
            as Map<String, dynamic>)["structuredContent"],
        containsPair("outcome", "invalidRequest"),
      );

      await tools.revokeMcp(capability: first);
      expect((await _mcpCall(server: server, token: first.bearerToken, name: "list_simulators")).statusCode, 401);
      await tools.dispose();
      expect((await _mcpCall(server: server, token: second.bearerToken, name: "list_simulators")).statusCode, 401);
    });

    test("allows MCP negotiation before a provisional capability is bound", () async {
      final tools = server.pluginHost(pluginId: "opencode");
      final capability = await tools.provisionMcp(backendSessionId: null);

      final initialized = await _mcpRequest(
        server: server,
        token: capability.bearerToken,
        method: "initialize",
        params: const {"protocolVersion": "2025-06-18"},
      );
      expect(initialized.body["result"], containsPair("protocolVersion", "2025-06-18"));
      final fallback = await _mcpRequest(
        server: server,
        token: capability.bearerToken,
        method: "initialize",
        params: const {"protocolVersion": "2099-01-01"},
      );
      expect(fallback.body["result"], containsPair("protocolVersion", "2025-06-18"));
      final unavailable = await _mcpCall(
        server: server,
        token: capability.bearerToken,
        name: "list_simulators",
      );
      expect(
        (unavailable.body["result"] as Map<String, dynamic>)["structuredContent"],
        containsPair("outcome", "sessionUnavailable"),
      );

      await tools.bindMcp(capability: capability, backendSessionId: "backend-2");
      await expectLater(
        tools.bindMcp(capability: capability, backendSessionId: "backend-1"),
        throwsStateError,
      );
      final available = await _mcpCall(server: server, token: capability.bearerToken, name: "list_simulators");
      expect(
        (available.body["result"] as Map<String, dynamic>)["structuredContent"],
        containsPair("outcome", "listed"),
      );
    });

    test("rejects missing protocol versions and browser origins on MCP requests", () async {
      final tools = server.pluginHost(pluginId: "opencode");
      final capability = await tools.provisionMcp(backendSessionId: "backend-1");
      try {
        expect(
          (await _request(
            server: server,
            route: "/mcp",
            token: capability.bearerToken,
            body: const {"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": <String, Object?>{}},
          )).statusCode,
          400,
        );
        expect(
          (await _request(
            server: server,
            route: "/mcp",
            token: capability.bearerToken,
            headers: const {"Origin": "https://example.com", "MCP-Protocol-Version": "2025-06-18"},
            body: const {"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": <String, Object?>{}},
          )).statusCode,
          403,
        );
      } finally {
        await tools.dispose();
      }
    });

    test("direct native invocation accepts only tool arguments", () async {
      final tools = server.pluginHost(pluginId: "opencode");
      expect(
        await tools.invoke(
          backendSessionId: "backend-1",
          tool: PluginAgentTool.claimSimulator,
          arguments: const {"deviceKey": "ios:booted"},
        ),
        containsPair("outcome", "claimed"),
      );
      expect(
        await tools.invoke(
          backendSessionId: "backend-1",
          tool: PluginAgentTool.releaseSimulator,
          arguments: const {"backendSessionId": "backend-2", "deviceKey": "ios:booted"},
        ),
        containsPair("outcome", "invalidRequest"),
      );
    });

    test("revocation waits for an authorized MCP operation to settle", () async {
      final blockingService = _BlockingAgentToolService();
      final blockingServer = DeviceCanvasAgentToolServer(
        service: blockingService,
        rendezvousRepository: DeviceCanvasAgentToolRendezvousRepository(
          filePath: path.join(tempDirectory.path, "blocking-rendezvous.json"),
        ),
        pluginId: "opencode",
        bootstrapSecret: bootstrapSecret,
      );
      await blockingServer.start();
      final tools = blockingServer.pluginHost(pluginId: "opencode");
      final capability = await tools.provisionMcp(backendSessionId: "backend-1");
      try {
        final call = _mcpCall(
          server: blockingServer,
          token: capability.bearerToken,
          name: "claim_simulator",
          arguments: const {"deviceKey": "ios:booted"},
        );
        await blockingService.started.future;

        var revoked = false;
        final revocation = tools.revokeMcp(capability: capability).then((_) => revoked = true);
        await Future<void>.delayed(Duration.zero);
        expect(revoked, isFalse);

        blockingService.complete();
        expect(
          ((await call).body["result"] as Map<String, dynamic>)["structuredContent"],
          containsPair("outcome", "claimed"),
        );
        await revocation;
        expect(revoked, isTrue);
        expect(
          (await _mcpCall(
            server: blockingServer,
            token: capability.bearerToken,
            name: "list_simulators",
          )).statusCode,
          401,
        );
      } finally {
        blockingService.complete();
        await tools.dispose();
        await blockingServer.dispose();
      }
    });

    test("host disposal revokes every MCP capability before waiting for a drain", () async {
      final blockingService = _BlockingAgentToolService();
      final blockingServer = DeviceCanvasAgentToolServer(
        service: blockingService,
        rendezvousRepository: DeviceCanvasAgentToolRendezvousRepository(
          filePath: path.join(tempDirectory.path, "multi-revoke-rendezvous.json"),
        ),
        pluginId: "opencode",
        bootstrapSecret: bootstrapSecret,
      );
      await blockingServer.start();
      final tools = blockingServer.pluginHost(pluginId: "opencode");
      final blocked = await tools.provisionMcp(backendSessionId: "backend-1");
      final idle = await tools.provisionMcp(backendSessionId: "backend-2");
      try {
        final call = _mcpCall(
          server: blockingServer,
          token: blocked.bearerToken,
          name: "claim_simulator",
          arguments: const {"deviceKey": "ios:booted"},
        );
        await blockingService.started.future;

        var disposed = false;
        final disposal = tools.dispose().then((_) => disposed = true);
        await Future<void>.delayed(Duration.zero);
        expect(disposed, isFalse);
        expect(
          (await _mcpCall(server: blockingServer, token: idle.bearerToken, name: "list_simulators")).statusCode,
          401,
        );

        blockingService.complete();
        await call;
        await disposal;
        expect(disposed, isTrue);
      } finally {
        blockingService.complete();
        await tools.dispose();
        await blockingServer.dispose();
      }
    });

    test("host disposal fences and drains native invocations", () async {
      final blockingService = _BlockingAgentToolService();
      final blockingServer = DeviceCanvasAgentToolServer(
        service: blockingService,
        rendezvousRepository: DeviceCanvasAgentToolRendezvousRepository(
          filePath: path.join(tempDirectory.path, "native-drain-rendezvous.json"),
        ),
        pluginId: "opencode",
        bootstrapSecret: bootstrapSecret,
      );
      await blockingServer.start();
      final tools = blockingServer.pluginHost(pluginId: "opencode");
      try {
        final invocation = tools.invoke(
          backendSessionId: "backend-1",
          tool: PluginAgentTool.claimSimulator,
          arguments: const {"deviceKey": "ios:booted"},
        );
        await blockingService.started.future;

        var disposed = false;
        final disposal = tools.dispose().then((_) => disposed = true);
        await Future<void>.delayed(Duration.zero);
        expect(disposed, isFalse);
        expect(
          await tools.invoke(
            backendSessionId: "backend-2",
            tool: PluginAgentTool.listSimulators,
            arguments: const {},
          ),
          containsPair("outcome", "bridgeUnavailable"),
        );

        blockingService.complete();
        expect(await invocation, containsPair("outcome", "claimed"));
        await disposal;
        expect(disposed, isTrue);
      } finally {
        blockingService.complete();
        await tools.dispose();
        await blockingServer.dispose();
      }
    });

    test("MCP service failures retain the JSON-RPC envelope and bounded outcome", () async {
      final failingServer = DeviceCanvasAgentToolServer(
        service: _FailingAgentToolService(),
        rendezvousRepository: DeviceCanvasAgentToolRendezvousRepository(
          filePath: path.join(tempDirectory.path, "failing-rendezvous.json"),
        ),
        pluginId: "opencode",
        bootstrapSecret: bootstrapSecret,
      );
      await failingServer.start();
      final tools = failingServer.pluginHost(pluginId: "opencode");
      final capability = await tools.provisionMcp(backendSessionId: "backend-1");
      try {
        final response = await _mcpCall(
          server: failingServer,
          token: capability.bearerToken,
          name: "list_simulators",
        );
        expect(response.statusCode, 200);
        expect(response.body["jsonrpc"], "2.0");
        expect(response.body["id"], 1);
        expect(response.body["result"], {
          "content": [
            {"type": "text", "text": '{"outcome":"internalError"}'},
          ],
          "structuredContent": {"outcome": "internalError"},
          "isError": true,
        });
      } finally {
        await tools.dispose();
        await failingServer.dispose();
      }
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

Future<_HttpResponse> _mcpCall({
  required DeviceCanvasAgentToolServer server,
  required String token,
  required String name,
  Map<String, Object?> arguments = const {},
}) => _mcpRequest(
  server: server,
  token: token,
  method: "tools/call",
  params: {"name": name, "arguments": arguments},
);

Future<_HttpResponse> _mcpRequest({
  required DeviceCanvasAgentToolServer server,
  required String token,
  required String method,
  Map<String, Object?> params = const {},
}) => _request(
  server: server,
  route: "/mcp",
  token: token,
  headers: method == "initialize" ? const {} : const {"MCP-Protocol-Version": "2025-06-18"},
  body: {"jsonrpc": "2.0", "id": 1, "method": method, "params": params},
);

Future<_HttpResponse> _request({
  required DeviceCanvasAgentToolServer server,
  required String route,
  required String token,
  String method = "POST",
  Map<String, Object?>? body,
  String? rawBody,
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      method,
      Uri.parse("http://127.0.0.1:${server.boundPort}$route"),
    );
    request.headers.set(HttpHeaders.authorizationHeader, "Bearer $token");
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
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

class _BlockingAgentToolService() implements DeviceCanvasAgentToolService {
  final Completer<void> started = Completer<void>();
  final Completer<void> _completion = Completer<void>();

  void complete() {
    if (!_completion.isCompleted) _completion.complete();
  }

  @override
  Future<DeviceCanvasAgentToolResult> claimSimulator({
    required String pluginId,
    required String backendSessionId,
    required String deviceKey,
  }) async {
    if (!started.isCompleted) started.complete();
    await _completion.future;
    return DeviceCanvasAgentSimulatorClaimed(deviceKey: deviceKey);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError("Unexpected call: ${invocation.memberName}");
}

class _FailingAgentToolService() implements DeviceCanvasAgentToolService {
  @override
  Future<DeviceCanvasAgentToolResult> listSimulators({
    required String pluginId,
    required String backendSessionId,
  }) async => throw StateError("private service detail");

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
