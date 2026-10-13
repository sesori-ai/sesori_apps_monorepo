import "dart:convert";

import "package:drift/drift.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/mcp_repository.dart";
import "package:sesori_bridge/src/routing/post_mcp_inventory_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_derived_bridge_plugin.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  late AppDatabase db;
  late _InventoryPlugin plugin;
  late TestPluginRuntime runtime;
  late PostMcpInventoryHandler handler;

  setUp(() async {
    db = createTestDatabase();
    plugin = _InventoryPlugin();
    runtime = createTestPluginRuntime(plugins: [plugin]);
    handler = PostMcpInventoryHandler(
      mcpRepository: McpRepository(
        runtime: runtime,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
      ),
    );
    await recordSessionBinding(
      database: db,
      sessionId: "bridge-session",
      backendSessionId: "native-session",
      pluginId: "fixture",
      projectId: "opaque-project",
      parentSessionId: null,
    );
    await (db.update(db.projectsTable)..where((row) => row.projectId.equals("opaque-project"))).write(
      const ProjectsTableCompanion(path: Value("/fixture/moved-project")),
    );
  });
  tearDown(() async {
    await runtime.dispose();
    await db.close();
  });

  Future<RelayResponse> read({required String pluginId, required McpScope scope}) => handler.routeForTest(
    makeRequest(
      "POST",
      "/mcp/inventory",
      body: jsonEncode(McpInventoryRequest(pluginId: pluginId, scope: scope)),
    ),
  );
  McpInventoryResult decode(RelayResponse response) => McpInventoryResult.fromJson(
    jsonDecode(response.body!) as Map<String, dynamic>,
  );

  test("maps bridge session IDs to native IDs and rebinds returned server targets", () async {
    final response = await read(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
    );
    expect(response.status, 200);
    expect((plugin.scopes.single as PluginMcpSessionScope).sessionId, "native-session");
    final result = decode(response) as McpInventorySnapshot;
    final server = result.entries.single as McpServerSnapshot;
    expect(server.serverTarget.scope, const McpSessionScope(sessionId: "bridge-session"));
    expect(server.serverTarget.serverKey, "opaque-server");
    expect(server.tools, isA<McpToolsFailed>());
    expect(result.connectors, isA<McpCatalogUnavailable>());
    expect(response.body, isNot(contains("native-session")));
  });

  test("rejects mismatched owner and missing session before accessing plugins", () async {
    expect(
      (await read(
        pluginId: "another",
        scope: const McpSessionScope(sessionId: "bridge-session"),
      )).status,
      400,
    );
    expect(
      (await read(
        pluginId: "fixture",
        scope: const McpSessionScope(sessionId: "missing"),
      )).status,
      404,
    );
    expect(plugin.scopes, isEmpty);
  });

  test("resolves current project path without treating an opaque project ID as a path", () async {
    final response = await read(
      pluginId: "fixture",
      scope: const McpProjectScope(projectId: "opaque-project"),
    );
    expect(response.status, 200);
    expect((plugin.scopes.single as PluginMcpProjectScope).projectId, "/fixture/moved-project");
    expect((decode(response) as McpInventorySnapshot).scope, const McpProjectScope(projectId: "opaque-project"));
    expect(
      (await read(
        pluginId: "fixture",
        scope: const McpProjectScope(projectId: "/unregistered/path"),
      )).status,
      404,
    );
    expect(plugin.scopes, hasLength(1));
  });

  test("inactive integration is explicit and inventory never activates it", () async {
    runtime.stoppedPluginIds.add("fixture");
    final result = decode(await read(pluginId: "fixture", scope: const McpHarnessScope()));
    expect((result as McpInventoryUnavailable).reason, McpInventoryUnavailableReason.pluginInactive);
    expect(plugin.scopes, isEmpty);
    expect(runtime.stoppedPluginIds, contains("fixture"));
  });

  test("integration without the optional interface reports unavailable, not an empty catalog", () async {
    final unsupportedRuntime = createTestPluginRuntime(
      plugins: [
        FakeDerivedBridgePlugin(id: "unsupported", launchDirectory: "/fixture", allSessions: const []),
      ],
    );
    final unsupportedHandler = PostMcpInventoryHandler(
      mcpRepository: McpRepository(
        runtime: unsupportedRuntime,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
      ),
    );
    final response = await unsupportedHandler.routeForTest(
      makeRequest(
        "POST",
        "/mcp/inventory",
        body: jsonEncode(
          const McpInventoryRequest(pluginId: "unsupported", scope: McpHarnessScope()),
        ),
      ),
    );
    expect(response.status, 200);
    expect((decode(response) as McpInventoryUnavailable).reason, McpInventoryUnavailableReason.unsupportedHarness);
    await unsupportedRuntime.dispose();
  });

  test("rejects empty IDs and invalid scope JSON at the transport boundary", () async {
    expect((await read(pluginId: "", scope: const McpHarnessScope())).status, 400);
    expect(
      (await read(
        pluginId: "fixture",
        scope: const McpSessionScope(sessionId: ""),
      )).status,
      400,
    );
    final malformed = await handler.routeForTest(
      makeRequest("POST", "/mcp/inventory", body: '{"pluginId":"fixture","scope":{"type":"unknown"}}'),
    );
    expect(malformed.status, 400);
    expect(plugin.scopes, isEmpty);
  });
}

class _InventoryPlugin() extends FakeDerivedBridgePlugin implements McpManagementPluginApi {
  this : super(id: "fixture", launchDirectory: "/fixture", allSessions: const []);
  final List<PluginMcpScope> scopes = [];

  @override
  Future<PluginMcpInventoryResult> getMcpInventory({required PluginMcpScope scope}) async {
    scopes.add(scope);
    return PluginMcpInventorySnapshot(
      entries: List.unmodifiable([
        PluginMcpServerSnapshot(
          target: PluginMcpServerTarget(scope: scope, serverKey: "opaque-server"),
          name: "Fixture",
          description: null,
          endpointOrigin: null,
          connection: const PluginMcpConnectionStatus(phase: PluginMcpConnectionPhase.connected),
          authorization: PluginMcpAuthorizationState.unknown,
          configuration: null,
          tools: const PluginMcpToolsFailed(message: "Discovery failed"),
        ),
      ]),
      connectors: const PluginMcpCatalogUnavailable(message: "Catalog unavailable"),
    );
  }
}
