import "dart:convert";
import "dart:io";
import "dart:math";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/foundation/sesori_mcp_server.dart";
import "package:sesori_bridge/src/repositories/sesori_mcp_grant_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/sesori_mcp_request_dispatcher.dart";
import "package:sesori_bridge/src/services/sesori_mcp_access_service.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/test_database.dart";

void main() {
  late SesoriMcpGrantRepository grants;
  late SesoriMcpServer server;
  late String token;
  var nextId = 1;

  setUp(() async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final plugin = FakeBridgePlugin();
    final sessions = singlePluginSessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    grants = SesoriMcpGrantRepository(random: Random.secure());
    server = await SesoriMcpServer.bindLoopback();
    addTearDown(server.close);
    final dispatcher = SesoriMcpRequestDispatcher(
      access: SesoriMcpAccessService(grants: grants, sessions: sessions),
    );
    // As the Orchestrator wires it.
    final subscription = server.requests.listen((request) async {
      await request.respond(
        reply: await dispatcher.dispatch(token: request.token, body: request.body),
      );
    });
    addTearDown(() async {
      await subscription.cancel();
      await dispatcher.drain();
    });

    token = grants.mint(pluginId: plugin.id);
    grants.bind(token: token, backendSessionId: "backend-s1");
  });

  Future<http.Response> post({required String bearer, required Map<String, Object?> message}) {
    return http.post(
      server.url,
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $bearer"},
      body: jsonEncode(message),
    );
  }

  Future<Map<String, dynamic>> rpc({
    required String method,
    required Map<String, Object?>? params,
    String? bearer,
  }) async {
    final response = await post(
      bearer: bearer ?? token,
      message: {"jsonrpc": "2.0", "id": nextId++, "method": method, "params": ?params},
    );
    expect(response.statusCode, HttpStatus.ok);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  group("protocol", () {
    test("initialize echoes a known protocol version and names the server", () async {
      final response = await rpc(method: "initialize", params: {"protocolVersion": "2025-06-18"});

      final result = response["result"] as Map<String, dynamic>;
      expect(response["id"], isNotNull);
      expect(result["protocolVersion"], "2025-06-18");
      expect(result["serverInfo"], containsPair("name", "sesori_bridge"));
      expect(result["capabilities"], {
        "tools": {"listChanged": false},
      });
    });

    test("initialize offers its newest version for an unknown one", () async {
      final response = await rpc(method: "initialize", params: {"protocolVersion": "1999-01-01"});

      expect((response["result"] as Map<String, dynamic>)["protocolVersion"], "2025-11-25");
    });

    test("a notification is accepted without a body", () async {
      final response = await post(
        bearer: token,
        message: {"jsonrpc": "2.0", "method": "notifications/initialized"},
      );

      expect(response.statusCode, HttpStatus.accepted);
      expect(response.body, isEmpty);
    });

    test("ping answers and tools/list lists no tools yet", () async {
      expect((await rpc(method: "ping", params: null))["result"], <String, dynamic>{});
      expect((await rpc(method: "tools/list", params: null))["result"], {"tools": <dynamic>[]});
    });

    test("malformed JSON, unknown methods and unknown tools are JSON-RPC errors", () async {
      final malformed = await http.post(
        server.url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: "{not json",
      );
      expect((jsonDecode(malformed.body) as Map<String, dynamic>)["error"], containsPair("code", -32700));
      expect((await rpc(method: "resources/list", params: null))["error"], containsPair("code", -32601));
      expect(
        (await rpc(method: "tools/call", params: {"name": "delete_everything"}))["error"],
        containsPair("code", -32602),
      );
    });
  });

  group("caller identity", () {
    test("a token this bridge never minted gets 401 for every method", () async {
      final response = await post(
        bearer: "made-up",
        message: {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": <String, Object?>{}},
      );

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test("a token from before a restart gets 401", () async {
      final oldBridge = SesoriMcpGrantRepository(random: Random.secure());
      final stale = oldBridge.mint(pluginId: "fake");
      oldBridge.bind(token: stale, backendSessionId: "backend-s1");

      final response = await post(bearer: stale, message: {"jsonrpc": "2.0", "id": 1, "method": "tools/list"});

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test("a launch not yet bound can connect", () async {
      final unbound = grants.mint(pluginId: "fake");

      expect((await rpc(method: "initialize", params: {}, bearer: unbound))["result"], isNotNull);
      expect((await rpc(method: "tools/list", params: null, bearer: unbound))["result"], isNotNull);
    });
  });
}
