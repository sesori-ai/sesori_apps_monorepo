import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/create_session_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("CreateSessionHandler", () {
    late FakeBridgePlugin plugin;
    late CreateSessionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = CreateSessionHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /session", () {
      expect(handler.canHandle(makeRequest("POST", "/session")), isTrue);
    });

    test("does not handle GET /session", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("returns 400 when request body is empty", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("returns 200 with null body", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: "Created",
        time: null,
        summary: null,
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: jsonEncode(
            const CreateSessionRequest(id: "new-session", projectId: "/tmp").toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastCreateSessionProjectId, equals("/tmp"));
      expect(plugin.lastCreateSessionId, equals("new-session"));
      expect(response.status, equals(200));
      expect(response.body, isNull);
    });

    test("returns 400 on invalid JSON body", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/session",
          body: "not-json",
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });
  });
}
