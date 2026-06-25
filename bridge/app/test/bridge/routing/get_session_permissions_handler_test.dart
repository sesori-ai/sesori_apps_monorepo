import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_permissions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetSessionPermissionsHandler", () {
    late FakeBridgePlugin plugin;
    late GetSessionPermissionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetSessionPermissionsHandler(permissionRepository: PermissionRepository(plugin: plugin));
    });

    tearDown(() => plugin.close());

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

    test("maps plugin permissions to shared, preserving displaySessionId", () async {
      plugin.pendingPermissionsResult = [
        const PluginPendingPermission(
          id: "p-1",
          sessionID: "child",
          displaySessionId: "root",
          tool: "bash",
          description: "Run ls",
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
    });
  });
}
