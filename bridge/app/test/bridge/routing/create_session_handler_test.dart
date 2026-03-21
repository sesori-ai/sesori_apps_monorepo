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

    test("returns 200 with created session body", () async {
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
            const CreateSessionRequest(projectId: "/tmp", parentSessionId: "parent-1").toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastCreateSessionProjectId, equals("/tmp"));
      expect(plugin.lastCreateSessionParentId, equals("parent-1"));
      expect(response.status, equals(200));
      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body["id"], equals("s1"));
      expect(body["projectID"], equals("p1"));
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
