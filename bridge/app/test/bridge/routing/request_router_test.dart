import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/request_router.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("RequestRouter", () {
    late FakeBridgePlugin plugin;
    late RequestRouter router;

    setUp(() {
      plugin = FakeBridgePlugin();
      router = RequestRouter(plugin);
    });

    tearDown(() => plugin.close());

    test("routes GET /global/health to HealthCheckHandler", () async {
      final response = await router.route(makeRequest("GET", "/global/health"));
      expect(response.status, equals(200));
      expect(response.body, equals('{"status":"ok"}'));
    });

    test("routes GET /project to GetProjectsHandler", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", worktree: "/tmp", name: "P"),
      ];
      final response = await router.route(makeRequest("GET", "/project"));
      expect(response.status, equals(200));
      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(1));
    });

    test("routes GET /session to GetSessionsHandler", () async {
      final response = await router.route(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
      );
      expect(response.status, equals(200));
    });

    test("GET /session without x-project-id header returns 400", () async {
      final response = await router.route(makeRequest("GET", "/session"));
      expect(response.status, equals(400));
    });

    test("routes GET /session/:id/message to GetSessionMessagesHandler", () async {
      await router.route(makeRequest("GET", "/session/abc/message"));
      expect(plugin.lastGetMessagesSessionId, equals("abc"));
    });

    test("path params are extracted and forwarded correctly", () async {
      await router.route(makeRequest("GET", "/session/sess-99/message"));
      expect(plugin.lastGetMessagesSessionId, equals("sess-99"));
    });

    test("query params are forwarded to handler", () async {
      await router.route(
        makeRequest(
          "GET",
          "/session?start=3&limit=7",
          headers: {"x-project-id": "/tmp"},
        ),
      );
      expect(plugin.lastGetSessionsStart, equals(3));
      expect(plugin.lastGetSessionsLimit, equals(7));
    });

    test("unknown route returns 404", () async {
      final response = await router.route(makeRequest("GET", "/unknown"));

      expect(response.status, equals(404));
      expect(response.body, equals("no handler found for GET /unknown"));
    });

    test("routes POST /session to CreateSessionHandler", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: null,
        summary: null,
      );

      final response = await router.route(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(projectId: "/tmp", parentSessionId: "parent-1").toJson(),
          ),
        ),
      );

      expect(response.status, equals(200));
      expect(plugin.lastCreateSessionProjectId, equals("/tmp"));
      expect(plugin.lastCreateSessionParentId, equals("parent-1"));
    });

    test("routes DELETE /session/:id to DeleteSessionHandler", () async {
      final response = await router.route(makeRequest("DELETE", "/session/abc"));
      expect(response.status, equals(200));
      expect(plugin.lastDeleteSessionId, equals("abc"));
    });

    test("routes GET /agent to GetAgentsHandler", () async {
      final response = await router.route(makeRequest("GET", "/agent"));
      expect(response.status, equals(200));
    });

    test("routes GET /question to GetPendingQuestionsHandler", () async {
      final response = await router.route(makeRequest("GET", "/question"));
      expect(response.status, equals(200));
    });

    test("returns 502 when handler throws", () async {
      plugin.throwOnGetProjects = true;
      final response = await router.route(makeRequest("GET", "/project"));
      expect(response.status, equals(502));
      expect(response.body, contains("request failed"));
    });

    test("returns upstream status when handler throws PluginApiException", () async {
      plugin.throwOnGetProjectsError = PluginApiException("/project", 404);

      final response = await router.route(makeRequest("GET", "/project"));

      expect(response.status, equals(404));
      expect(response.body, contains("PluginApiException"));
    });

    test("502 body contains the original error message", () async {
      plugin.throwOnHealthCheck = true;
      final response = await router.route(makeRequest("GET", "/global/health"));
      expect(response.status, equals(502));
      expect(response.body, contains("healthCheck error"));
    });
  });
}
