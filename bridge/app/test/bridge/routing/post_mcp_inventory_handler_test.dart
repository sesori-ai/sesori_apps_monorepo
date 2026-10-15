import "dart:async";
import "dart:convert";

import "package:drift/drift.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/mcp_repository.dart";
import "package:sesori_bridge/src/repositories/models/mcp_control_result.dart";
import "package:sesori_bridge/src/routing/post_mcp_entry_action_handler.dart";
import "package:sesori_bridge/src/routing/post_mcp_inventory_handler.dart";
import "package:sesori_bridge/src/services/mcp_authentication_service.dart";
import "package:sesori_bridge/src/services/mcp_service.dart";
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
  late McpService service;
  late McpAuthenticationService authentication;
  late PostMcpEntryActionHandler actionHandler;
  final changes = <McpInventoryRequest>[];

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
    authentication = McpAuthenticationService(
      repository: McpRepository(runtime: runtime, sessionDao: db.sessionDao, projectsDao: db.projectsDao),
    );
    service = McpService(
      authenticationService: authentication,
      repository: McpRepository(runtime: runtime, sessionDao: db.sessionDao, projectsDao: db.projectsDao),
    );
    actionHandler = PostMcpEntryActionHandler(mcpService: service);
    changes.clear();
    service.inventoryChanges.listen(changes.add);
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
    await authentication.dispose();
    await service.dispose();
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

  Future<RelayResponse> act({required String pluginId, required McpScope scope, required McpServerAction action}) =>
      actionHandler.routeForTest(
        makeRequest(
          "POST",
          "/mcp/entry/action",
          body: jsonEncode(
            McpEntryActionRequest(
              pluginId: pluginId,
              action: McpServerEntryAction(
                target: McpServerTarget(scope: scope, serverKey: "opaque-server"),
                action: action,
              ),
            ),
          ),
        ),
      );

  test("unknown actions and mismatched targets reject before native access", () async {
    for (final type in [null, "future", "connectorSetup"]) {
      final body = const McpEntryActionRequest(
        pluginId: "fixture",
        action: McpServerEntryAction(
          target: McpServerTarget(
            scope: McpSessionScope(sessionId: "bridge-session"),
            serverKey: "opaque-server",
          ),
          action: McpServerAction.enable,
        ),
      ).toJson();
      (body["action"] as Map<String, dynamic>)["type"] = type;
      final response = await actionHandler.routeForTest(
        makeRequest("POST", "/mcp/entry/action", body: jsonEncode(body)),
      );
      expect(response.status, 400);
    }
    expect(plugin.actions, isEmpty);
    expect(plugin.scopes, isEmpty);
    expect(changes, isEmpty);
  });

  Future<RelayResponse> setup({required String pluginId, required McpScope scope}) => actionHandler.routeForTest(
    makeRequest(
      "POST",
      "/mcp/entry/action",
      body: jsonEncode(
        McpEntryActionRequest(
          pluginId: pluginId,
          action: McpConnectorSetupEntryAction(
            offerTarget: McpConnectorOfferTarget(scope: scope, offerKey: "opaque-server"),
          ),
        ),
      ),
    ),
  );

  test("connector setup resolves the native offer without server mutation or invalidation", () async {
    final response = await setup(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
    );
    expect(response.status, 200);
    final result =
        McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>) as McpExternalSetup;
    expect(result.setupUrl, "https://fixture.example/setup?private=secret");
    expect(result.toString(), isNot(contains("private=secret")));
    expect(plugin.setupTargets.single.offerKey, "opaque-server");
    expect((plugin.setupTargets.single.scope as PluginMcpSessionScope).sessionId, "native-session");
    expect(plugin.actions, isEmpty);
    expect(plugin.scopes, isEmpty);
    expect(changes, isEmpty);
  });

  test("bridge rejects unsafe plugin setup destinations before forwarding", () async {
    for (final url in [
      "/setup",
      "http://fixture.example",
      "file:///setup",
      "data:text/plain,setup",
      "javascript:void(0)",
      "custom://setup",
      "https://user:secret@fixture.example",
    ]) {
      plugin.setupResult = PluginMcpConnectorExternalSetup(destination: Uri.parse(url));
      final response = await setup(pluginId: "fixture", scope: const McpHarnessScope());
      expect(
        McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>),
        const McpActionUnavailable(reason: McpActionUnavailableReason.nativeConfigurationRequired),
      );
      expect(response.body, isNot(contains(url)));
    }
    expect(changes, isEmpty);
  });

  test("setup checks archived and foreign session ownership before plugin access", () async {
    expect(
      (await setup(
        pluginId: "other",
        scope: const McpSessionScope(sessionId: "bridge-session"),
      )).status,
      400,
    );
    expect(
      (await setup(
        pluginId: "fixture",
        scope: const McpSessionScope(sessionId: "missing"),
      )).status,
      404,
    );
    await (db.update(
      db.sessionTable,
    )..where((r) => r.sessionId.equals("bridge-session"))).write(const SessionTableCompanion(archivedAt: Value(1)));
    expect(
      (await setup(
        pluginId: "fixture",
        scope: const McpSessionScope(sessionId: "bridge-session"),
      )).status,
      409,
    );
    expect(plugin.setupTargets, isEmpty);
    expect(changes, isEmpty);
  });

  test("native setup failure stays a safe typed response", () async {
    plugin.setupResult = PluginMcpConnectorSetupFailed(
      cause: Exception("fixture-secret"),
      causeStackTrace: StackTrace.current,
    );
    final response = await setup(pluginId: "fixture", scope: const McpHarnessScope());
    expect(McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>), isA<McpActionFailed>());
    expect(response.body, isNot(contains("fixture-secret")));
    expect(changes, isEmpty);
  });

  Future<RelayResponse> forget({required String pluginId, required McpServerTarget target}) =>
      actionHandler.routeForTest(
        makeRequest(
          "POST",
          "/mcp/entry/action",
          body: jsonEncode(
            McpEntryActionRequest(
              pluginId: pluginId,
              action: McpForgetAuthenticationEntryAction(target: target),
            ),
          ),
        ),
      );
  const forgettingTarget = McpServerTarget(
    scope: McpSessionScope(sessionId: "bridge-session"),
    serverKey: "opaque-server",
  );

  test("credential forgetting binds the native target, invalidates its native scope and reads inventory", () async {
    final response = await forget(pluginId: "fixture", target: forgettingTarget);
    expect(response.status, 200);
    final result =
        McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>) as McpActionCompleted;
    final server = (result.inventory as McpInventorySnapshot).entries.single as McpServerSnapshot;
    expect(server.serverTarget, forgettingTarget);
    expect(server.connection, const McpConnectionStatus(phase: McpConnectionPhase.connected));
    expect(server.authorization, McpAuthorizationState.unknown);
    expect(
      server.authentication,
      const McpAuthenticationCapabilityAvailable(effectScope: McpActionEffectScope.harness),
    );
    expect(
      server.credentialForgetting,
      const McpAuthenticationCapabilityAvailable(effectScope: McpActionEffectScope.harness),
    );
    expect((plugin.forgotten.single.scope as PluginMcpSessionScope).sessionId, "native-session");
    expect(plugin.forgotten.single.serverKey, forgettingTarget.serverKey);
    expect(plugin.actions, isEmpty);
    expect(changes.single.scope, const McpHarnessScope());
    expect((plugin.scopes.single as PluginMcpSessionScope).sessionId, "native-session");
  });

  test("forgetting uses the native declared scope rather than assuming a profile effect", () async {
    plugin.forgettingScope = PluginMcpActionEffectScope.session;
    await forget(pluginId: "fixture", target: forgettingTarget);
    expect(changes.single.scope, forgettingTarget.scope);
  });

  test("missing, mismatched, archived and inactive targets never clear credentials", () async {
    expect(
      (await forget(
        pluginId: "fixture",
        target: const McpServerTarget(
          scope: McpSessionScope(sessionId: "missing"),
          serverKey: "opaque-server",
        ),
      )).status,
      404,
    );
    expect((await forget(pluginId: "another", target: forgettingTarget)).status, 400);
    await (db.update(
      db.sessionTable,
    )..where((row) => row.sessionId.equals("bridge-session"))).write(const SessionTableCompanion(archivedAt: Value(1)));
    final archived = await forget(pluginId: "fixture", target: forgettingTarget);
    expect(archived.status, 409);
    expect(
      SessionArchivedRejection.fromJson(jsonDecode(archived.body!) as Map<String, dynamic>).reason,
      SessionArchivedReason.archivedReadOnly,
    );
    await (db.update(db.sessionTable)..where((row) => row.sessionId.equals("bridge-session"))).write(
      const SessionTableCompanion(archivedAt: Value(null)),
    );
    runtime.stoppedPluginIds.add("fixture");
    final inactive = await forget(pluginId: "fixture", target: forgettingTarget);
    expect(
      McpEntryActionResult.fromJson(jsonDecode(inactive.body!) as Map<String, dynamic>),
      const McpActionUnavailable(reason: McpActionUnavailableReason.pluginInactive),
    );
    expect(plugin.forgotten, isEmpty);
    expect(plugin.scopes, isEmpty);
    expect(changes, isEmpty);
  });

  test("native capability gaps and failure remain explicit without inventing logout state", () async {
    for (final (nativeReason, expected) in [
      (PluginMcpAuthenticationUnavailableReason.unsupportedScope, McpActionUnavailableReason.unsupportedScope),
      (PluginMcpAuthenticationUnavailableReason.liveSessionRequired, McpActionUnavailableReason.liveSessionRequired),
      (PluginMcpAuthenticationUnavailableReason.targetNotFound, McpActionUnavailableReason.targetNotFound),
      (
        PluginMcpAuthenticationUnavailableReason.nativeConfigurationRequired,
        McpActionUnavailableReason.nativeConfigurationRequired,
      ),
      (PluginMcpAuthenticationUnavailableReason.notSupported, McpActionUnavailableReason.notSupported),
      (PluginMcpAuthenticationUnavailableReason.notImplemented, McpActionUnavailableReason.notImplemented),
    ]) {
      plugin.forgettingError = PluginMcpAuthenticationUnavailableException(reason: nativeReason);
      final response = await forget(pluginId: "fixture", target: forgettingTarget);
      expect(
        McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>),
        McpActionUnavailable(reason: expected),
      );
    }
    plugin.forgettingError = Exception("fixture-private");
    final failed = await forget(pluginId: "fixture", target: forgettingTarget);
    expect(McpEntryActionResult.fromJson(jsonDecode(failed.body!) as Map<String, dynamic>), const McpActionFailed());
    expect(failed.body, isNot(contains("fixture-private")));
    expect(changes, isEmpty);
    expect(plugin.scopes, isEmpty);
    expect(authentication.current, const McpAuthenticationStateResult(state: McpAuthenticationIdle()));
  });

  test("controls resolve native identity, refresh authoritatively and invalidate their bridge scope", () async {
    final response = await act(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
      action: McpServerAction.reconnect,
    );
    expect(response.status, 200);
    final result =
        McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>) as McpActionCompleted;
    final (target, action) = plugin.actions.single;
    expect((target.scope as PluginMcpSessionScope).sessionId, "native-session");
    expect(action, PluginMcpServerAction.reconnect);
    expect((result.inventory as McpInventorySnapshot).scope, const McpSessionScope(sessionId: "bridge-session"));
    final server = (result.inventory as McpInventorySnapshot).entries.single as McpServerSnapshot;
    expect(server.actions.single.action, McpServerAction.reconnect);
    expect(server.actions.single.effectScope, McpActionEffectScope.session);
    expect(
      changes.single,
      const McpInventoryRequest(
        pluginId: "fixture",
        scope: McpSessionScope(sessionId: "bridge-session"),
      ),
    );
  });

  test("controls reject wrong owner, missing and archived sessions before native access", () async {
    expect(
      (await act(
        pluginId: "another",
        scope: const McpSessionScope(sessionId: "bridge-session"),
        action: McpServerAction.reconnect,
      )).status,
      400,
    );
    expect(
      (await act(
        pluginId: "fixture",
        scope: const McpSessionScope(sessionId: "missing"),
        action: McpServerAction.reconnect,
      )).status,
      404,
    );
    await (db.update(
      db.sessionTable,
    )..where((row) => row.sessionId.equals("bridge-session"))).write(const SessionTableCompanion(archivedAt: Value(1)));
    final archived = await act(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
      action: McpServerAction.reconnect,
    );
    expect(archived.status, 409);
    expect(archived.headers["content-type"], contains("application/json"));
    expect(
      SessionArchivedRejection.fromJson(jsonDecode(archived.body!) as Map<String, dynamic>),
      const SessionArchivedRejection(sessionId: "bridge-session", reason: SessionArchivedReason.archivedReadOnly),
    );
    expect(plugin.actions, isEmpty);
    expect(plugin.scopes, isEmpty);
    expect(changes, isEmpty);
  });

  test("session-targeted controls invalidate their native declared harness effect", () async {
    plugin.actionResult = const PluginMcpActionCompleted(effectScope: PluginMcpActionEffectScope.harness);
    final response = await act(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
      action: McpServerAction.reconnect,
    );
    expect(response.status, 200);
    expect(changes.single.scope, const McpHarnessScope());
    expect((plugin.scopes.single as PluginMcpSessionScope).sessionId, "native-session");
  });

  for (final scope in [
    const McpSessionScope(sessionId: "bridge-session"),
    const McpProjectScope(projectId: "opaque-project"),
  ]) {
    test("project-wide control invalidates every plugin view when invoked from $scope", () async {
      plugin.actionResult = const PluginMcpActionCompleted(effectScope: PluginMcpActionEffectScope.project);
      final response = await act(pluginId: "fixture", scope: scope, action: McpServerAction.reconnect);
      expect(response.status, 200);
      expect(changes.single, const McpInventoryRequest(pluginId: "fixture", scope: McpHarnessScope()));
      expect(
        ((McpEntryActionResult.fromJson(
                  jsonDecode(response.body!) as Map<String, dynamic>,
                ) as McpActionCompleted).inventory
                as McpInventorySnapshot)
            .scope,
        scope,
      );
    });
  }

  test("native control failure retains diagnostics locally without refreshing or exporting errors", () async {
    plugin.actionResult = PluginMcpActionFailed(
      cause: Exception("fixture-secret"),
      causeStackTrace: StackTrace.current,
    );
    final response = await act(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
      action: McpServerAction.reconnect,
    );
    expect(McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>), isA<McpActionFailed>());
    expect(response.body, isNot(contains("fixture-secret")));
    expect(plugin.scopes, isEmpty);
    expect(changes, isEmpty);
  });

  test("completed controls do not turn a failed authoritative refresh into connected state", () async {
    plugin.nextResult = PluginMcpInventoryReadFailed(
      cause: Exception("fixture-secret"),
      causeStackTrace: StackTrace.current,
    );
    final response = await act(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
      action: McpServerAction.enable,
    );
    final result =
        McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>) as McpActionCompleted;
    expect(
      result.inventory,
      isA<McpInventoryUnavailable>().having((r) => r.reason, "reason", McpInventoryUnavailableReason.readFailed),
    );
    expect(changes, hasLength(1));
  });

  test("inactive integrations and unknown controls never start a runtime", () async {
    runtime.stoppedPluginIds.add("fixture");
    final response = await act(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
      action: McpServerAction.reconnect,
    );
    expect(
      McpEntryActionResult.fromJson(jsonDecode(response.body!) as Map<String, dynamic>),
      isA<McpActionUnavailable>().having((r) => r.reason, "reason", McpActionUnavailableReason.pluginInactive),
    );
    expect(
      (await act(
        pluginId: "fixture",
        scope: const McpSessionScope(sessionId: "bridge-session"),
        action: McpServerAction.unknown,
      )).status,
      400,
    );
    expect(plugin.actions, isEmpty);
    expect(changes, isEmpty);
  });

  test("maps bridge session IDs to native IDs and rebinds returned server targets", () async {
    final response = await read(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
    );
    expect(response.status, 200);
    expect((plugin.scopes.single as PluginMcpSessionScope).sessionId, "native-session");
    final result = decode(response) as McpInventorySnapshot;
    expect(result.servers, isA<McpCatalogAvailable>());
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

  test("server-section failure preserves offered connectors and bridge-owned targets", () async {
    plugin.nextResult = const PluginMcpInventorySnapshot(
      servers: PluginMcpCatalogUnavailable(message: "Server discovery failed"),
      connectors: PluginMcpCatalogAvailable(),
      entries: [
        PluginMcpConnectorOfferSnapshot(
          target: PluginMcpConnectorOfferTarget(
            scope: PluginMcpSessionScope(sessionId: "native-session"),
            offerKey: "fixture-offer",
          ),
          name: "Fixture offer",
          description: null,
          availability: PluginMcpConnectorOfferAvailability.setupRequired,
          actions: [],
        ),
      ],
    );
    final result = decode(
      await read(
        pluginId: "fixture",
        scope: const McpSessionScope(sessionId: "bridge-session"),
      ),
    ) as McpInventorySnapshot;
    expect(result.servers, const McpCatalogUnavailable(message: "Server discovery failed"));
    expect(result.connectors, isA<McpCatalogAvailable>());
    final offer = result.entries.single as McpConnectorOfferSnapshot;
    expect(offer.offerTarget.scope, const McpSessionScope(sessionId: "bridge-session"));
    expect(offer.offerTarget.offerKey, "fixture-offer");
    expect(offer.availability, McpConnectorOfferAvailability.setupRequired);
  });

  test("native read failures return typed state without native error payloads", () async {
    plugin.nextResult = PluginMcpInventoryReadFailed(
      cause: Exception("https://fixture.test/private?token=fixture-secret"),
      causeStackTrace: StackTrace.current,
    );
    final response = await read(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
    );
    expect(response.status, 200);
    expect((decode(response) as McpInventoryUnavailable).reason, McpInventoryUnavailableReason.readFailed);
    expect(response.body, isNot(contains("fixture-secret")));
    expect(response.body, isNot(contains("fixture.test")));
  });

  test("archiving does not turn read-only inventory into a session mutation", () async {
    await (db.update(db.sessionTable)..where((row) => row.sessionId.equals("bridge-session"))).write(
      const SessionTableCompanion(archivedAt: Value(1)),
    );
    final response = await read(
      pluginId: "fixture",
      scope: const McpSessionScope(sessionId: "bridge-session"),
    );
    expect(response.status, 200);
    expect(decode(response), isA<McpInventorySnapshot>());
    expect((plugin.scopes.single as PluginMcpSessionScope).sessionId, "native-session");
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
    final unavailable =
        await McpRepository(
          runtime: unsupportedRuntime,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
        ).forgetAuthentication(
          pluginId: "unsupported",
          target: const McpServerTarget(scope: McpHarnessScope(), serverKey: "fixture"),
        );
    expect(
      unavailable,
      isA<McpControlUnavailable>().having((r) => r.reason, "reason", McpActionUnavailableReason.unsupportedHarness),
    );
    final setup =
        await McpRepository(
          runtime: unsupportedRuntime,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
        ).resolveConnectorSetup(
          pluginId: "unsupported",
          target: const McpConnectorOfferTarget(scope: McpHarnessScope(), offerKey: "fixture"),
        );
    expect(
      setup,
      isA<McpControlUnavailable>().having((r) => r.reason, "reason", McpActionUnavailableReason.unsupportedHarness),
    );
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

class _InventoryPlugin()
    extends FakeDerivedBridgePlugin
    implements McpManagementPluginApi, McpAuthenticationPluginApi, McpConnectorSetupPluginApi {
  this : super(id: "fixture", launchDirectory: "/fixture", allSessions: const []);
  final forgotten = <PluginMcpServerTarget>[];
  Exception? forgettingError;
  PluginMcpActionEffectScope forgettingScope = PluginMcpActionEffectScope.harness;
  final setupTargets = <PluginMcpConnectorOfferTarget>[];
  PluginMcpConnectorSetupResult setupResult = PluginMcpConnectorExternalSetup(
    destination: Uri.parse("https://fixture.example/setup?private=secret"),
  );

  @override
  Future<PluginMcpConnectorSetupResult> resolveMcpConnectorSetup({
    required PluginMcpConnectorOfferTarget target,
  }) async {
    setupTargets.add(target);
    return setupResult;
  }

  @override
  Future<PluginMcpAuthenticationOperation> beginMcpAuthentication({required PluginMcpServerTarget target}) =>
      throw UnimplementedError();

  @override
  Future<PluginMcpActionEffectScope> forgetMcpAuthentication({required PluginMcpServerTarget target}) async {
    forgotten.add(target);
    if (forgettingError case final error?) throw error;
    return forgettingScope;
  }

  @override
  Future<PluginMcpActionResult> executeMcpServerAction({
    required PluginMcpServerTarget target,
    required PluginMcpServerAction action,
  }) async {
    actions.add((target, action));
    return actionResult;
  }

  PluginMcpActionResult actionResult = const PluginMcpActionCompleted(effectScope: PluginMcpActionEffectScope.session);
  final actions = <(PluginMcpServerTarget, PluginMcpServerAction)>[];
  final List<PluginMcpScope> scopes = [];
  PluginMcpInventoryResult? nextResult;

  @override
  Future<PluginMcpInventoryResult> getMcpInventory({required PluginMcpScope scope}) async {
    scopes.add(scope);
    if (nextResult case final result?) return result;
    return PluginMcpInventorySnapshot(
      servers: const PluginMcpCatalogAvailable(),
      entries: List.unmodifiable([
        PluginMcpServerSnapshot(
          authentication: const PluginMcpAuthenticationCapabilityAvailable(
            effectScope: PluginMcpActionEffectScope.harness,
          ),
          credentialForgetting: const PluginMcpAuthenticationCapabilityAvailable(
            effectScope: PluginMcpActionEffectScope.harness,
          ),
          actions: const [
            PluginMcpServerActionCapability(
              action: PluginMcpServerAction.reconnect,
              effectScope: PluginMcpActionEffectScope.session,
            ),
          ],
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
