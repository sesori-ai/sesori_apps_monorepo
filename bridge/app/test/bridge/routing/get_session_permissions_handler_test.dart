import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_permissions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionPermissionsHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late GetSessionPermissionsHandler handler;

    setUp(() async {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      await recordSessionBinding(
        database: db,
        sessionId: "root",
        backendSessionId: "backend-root",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );
      await recordSessionBinding(
        database: db,
        sessionId: "child",
        backendSessionId: "backend-child",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: "root",
      );
      handler = GetSessionPermissionsHandler(
        permissionRepository: singlePluginPermissionRepository(plugin: plugin, sessionDao: db.sessionDao),
        suppressPendingPermissions: false,
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /session/permissions", () {
      expect(handler.canHandle(makeRequest("POST", "/session/permissions")), isTrue);
    });

    test("does not handle GET /session/permissions", () {
      expect(handler.canHandle(makeRequest("GET", "/session/permissions")), isFalse);
    });

    test("returns 400 when session id is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/permissions"),
          body: const SessionIdRequest(sessionId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns 400 for an empty session id when pending permissions are suppressed", () async {
      final suppressedHandler = GetSessionPermissionsHandler(
        permissionRepository: singlePluginPermissionRepository(plugin: plugin, sessionDao: db.sessionDao),
        suppressPendingPermissions: true,
      );

      await expectLater(
        () => suppressedHandler.handle(
          makeRequest("POST", "/session/permissions"),
          body: const SessionIdRequest(sessionId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("preserves not-found for an unknown session when pending permissions are suppressed", () async {
      final suppressedHandler = GetSessionPermissionsHandler(
        permissionRepository: singlePluginPermissionRepository(plugin: plugin, sessionDao: db.sessionDao),
        suppressPendingPermissions: true,
      );

      await expectLater(
        suppressedHandler.handle(
          makeRequest("POST", "/session/permissions"),
          body: const SessionIdRequest(sessionId: "unknown"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
    });

    test("returns no pending permissions when snapshot suppression is enabled", () async {
      plugin.pendingPermissionsResult = [
        const PluginPendingPermission(
          id: "p-1",
          sessionID: "backend-root",
          displaySessionId: "backend-root",
          tool: "bash",
          description: "Run ls",
          allowAlways: true,
        ),
      ];
      final suppressedHandler = GetSessionPermissionsHandler(
        permissionRepository: singlePluginPermissionRepository(plugin: plugin, sessionDao: db.sessionDao),
        suppressPendingPermissions: true,
      );

      final response = await suppressedHandler.handle(
        makeRequest("POST", "/session/permissions"),
        body: const SessionIdRequest(sessionId: "root"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, const PendingPermissionResponse(data: []));
    });

    test("maps plugin permissions to shared, preserving displaySessionId", () async {
      plugin.pendingPermissionsResult = [
        const PluginPendingPermission(
          id: "p-1",
          sessionID: "backend-child",
          displaySessionId: "backend-root",
          tool: "bash",
          description: "Run ls",
          allowAlways: false,
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/session/permissions"),
        body: const SessionIdRequest(sessionId: "root"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.data, isA<List<PendingPermission>>());
      final item = response.data.single;
      expect(item.id, equals("p-1"));
      expect(item.sessionID, equals("child"));
      expect(item.displaySessionId, equals("root"));
      expect(item.tool, equals("bash"));
      expect(item.description, equals("Run ls"));
      expect(item.allowAlways, isFalse);
    });

    test("does not query a derived plugin for a tombstoned session", () async {
      final derivedPlugin = _DerivedPermissionPlugin();
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone",
        pluginId: derivedPlugin.id,
        deletedAt: 1,
      );
      final repository = singlePluginPermissionRepository(
        plugin: derivedPlugin,
        sessionDao: db.sessionDao,
      );
      final derivedHandler = GetSessionPermissionsHandler(
        permissionRepository: repository,
        suppressPendingPermissions: false,
      );

      await expectLater(
        derivedHandler.handle(
          makeRequest("POST", "/session/permissions"),
          body: const SessionIdRequest(sessionId: "gone"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );

      expect(derivedPlugin.pendingPermissionCalls, isZero);
      await expectLater(
        repository.replyToPermission(
          requestId: "permission-gone",
          sessionId: "gone",
          reply: PermissionReply.reject,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
    });

    test("filters permissions for tombstoned child and displayed sessions", () async {
      final derivedPlugin = _DerivedPermissionPlugin()
        ..permissions = const [
          PluginPendingPermission(
            id: "deleted-child",
            sessionID: "gone-child",
            displaySessionId: "root",
            tool: "shell",
            description: "child",
            allowAlways: true,
          ),
          PluginPendingPermission(
            id: "deleted-root",
            sessionID: "live-child",
            displaySessionId: "gone-root",
            tool: "shell",
            description: "root",
            allowAlways: true,
          ),
          PluginPendingPermission(
            id: "visible",
            sessionID: "live-child",
            displaySessionId: "root",
            tool: "shell",
            description: "visible",
            allowAlways: true,
          ),
        ];
      await recordSessionBinding(
        database: db,
        sessionId: "stable-root",
        backendSessionId: "root",
        pluginId: derivedPlugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );
      await recordSessionBinding(
        database: db,
        sessionId: "stable-child",
        backendSessionId: "live-child",
        pluginId: derivedPlugin.id,
        projectId: "/repo",
        parentSessionId: "stable-root",
      );
      for (final sessionId in ["gone-child", "gone-root"]) {
        await db.sessionDao.insertSessionTombstone(
          backendSessionId: sessionId,
          pluginId: derivedPlugin.id,
          deletedAt: 1,
        );
      }
      final derivedHandler = GetSessionPermissionsHandler(
        permissionRepository: singlePluginPermissionRepository(
          plugin: derivedPlugin,
          sessionDao: db.sessionDao,
        ),
        suppressPendingPermissions: false,
      );

      final response = await derivedHandler.handle(
        makeRequest("POST", "/session/permissions"),
        body: const SessionIdRequest(sessionId: "stable-root"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.data.map((permission) => permission.id), ["visible"]);
      expect(response.data.single.sessionID, "stable-child");
      expect(response.data.single.displaySessionId, "stable-root");
    });

    test("permission replies reject a tombstoned displayed root", () async {
      final derivedPlugin = _DerivedPermissionPlugin()
        ..permissions = const [
          PluginPendingPermission(
            id: "permission-stale",
            sessionID: "live-child",
            displaySessionId: "gone-root",
            tool: "shell",
            description: "stale",
            allowAlways: true,
          ),
        ];
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone-root",
        pluginId: derivedPlugin.id,
        deletedAt: 1,
      );
      final repository = singlePluginPermissionRepository(
        plugin: derivedPlugin,
        sessionDao: db.sessionDao,
      );
      await recordSessionBinding(
        database: db,
        sessionId: "stable-child",
        backendSessionId: "live-child",
        pluginId: derivedPlugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );

      await expectLater(
        repository.replyToPermission(
          requestId: "permission-stale",
          sessionId: "stable-child",
          reply: PermissionReply.once,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(derivedPlugin.permissionReplyCalls, isZero);
    });

    test("permission replies reject a tombstoned owning descendant", () async {
      final derivedPlugin = _DerivedPermissionPlugin()
        ..permissions = const [
          PluginPendingPermission(
            id: "permission-stale-child",
            sessionID: "gone-child",
            displaySessionId: "live-root",
            tool: "shell",
            description: "stale child",
            allowAlways: true,
          ),
        ];
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone-child",
        pluginId: derivedPlugin.id,
        deletedAt: 1,
      );
      final repository = singlePluginPermissionRepository(
        plugin: derivedPlugin,
        sessionDao: db.sessionDao,
      );
      await recordSessionBinding(
        database: db,
        sessionId: "stable-root",
        backendSessionId: "live-root",
        pluginId: derivedPlugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );

      await expectLater(
        repository.replyToPermission(
          requestId: "permission-stale-child",
          sessionId: "stable-root",
          reply: PermissionReply.once,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(derivedPlugin.permissionReplyCalls, isZero);
    });
  });
}

class _DerivedPermissionPlugin implements BridgeDerivedProjectsPluginApi {
  int pendingPermissionCalls = 0;
  int permissionReplyCalls = 0;
  List<PluginPendingPermission> permissions = const [];

  @override
  String get id => "codex";

  @override
  String get launchDirectory => "/repo";

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async {
    pendingPermissionCalls++;
    return permissions;
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    permissionReplyCalls++;
  }

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async => const [];

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
