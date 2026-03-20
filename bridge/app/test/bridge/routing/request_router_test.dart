import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/request_router.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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
        makeRequest("GET", "/session", headers: {"x-opencode-directory": "/tmp"}),
      );
      expect(response.status, equals(200));
    });

    test("GET /session without header returns 400", () async {
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
          headers: {"x-opencode-directory": "/tmp"},
        ),
      );
      expect(plugin.lastGetSessionsStart, equals(3));
      expect(plugin.lastGetSessionsLimit, equals(7));
    });

    test("unknown GET route falls through to ProxyHandler", () async {
      plugin.proxyStatus = 404;
      plugin.proxyBody = "not found";

      final response = await router.route(makeRequest("GET", "/unknown/path"));

      expect(response.status, equals(404));
      expect(plugin.lastProxyPath, equals("/unknown/path"));
    });

    test("POST to a known path falls through to ProxyHandler", () async {
      plugin.proxyStatus = 201;
      final response = await router.route(
        makeRequest("POST", "/session", body: "{}"),
      );
      expect(response.status, equals(201));
      expect(plugin.lastProxyMethod, equals("POST"));
    });

    test("returns 502 when handler throws", () async {
      plugin.throwOnGetProjects = true;
      final response = await router.route(makeRequest("GET", "/project"));
      expect(response.status, equals(502));
      expect(response.body, contains("request failed"));
    });

    test("502 body contains the original error message", () async {
      plugin.throwOnHealthCheck = true;
      final response = await router.route(makeRequest("GET", "/global/health"));
      expect(response.status, equals(502));
      expect(response.body, contains("healthCheck error"));
    });
  });
}
