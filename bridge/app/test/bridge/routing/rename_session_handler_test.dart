import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/rename_session_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("RenameSessionHandler", () {
    late FakeBridgePlugin plugin;
    late RenameSessionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = RenameSessionHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle PATCH /session/title", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/title")), isTrue);
    });

    test("does not handle GET /session/title", () {
      expect(handler.canHandle(makeRequest("GET", "/session/title")), isFalse);
    });

    test("does not handle PATCH /session/:id/title", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/s1/title")), isFalse);
    });

    test("does not handle PATCH /session/:id", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/s1")), isFalse);
    });

    test("extracts sessionId and parses title from body", () async {
      plugin.renameSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: "New Title",
        time: null,
        summary: null,
      );

      await handler.handle(
        makeRequest(
          "PATCH",
          "/session/title",
          body: jsonEncode(const RenameSessionRequest(sessionId: "s1", title: "New Title").toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastRenameSessionId, equals("s1"));
      expect(plugin.lastRenameSessionTitle, equals("New Title"));
    });

    test("returns 400 when body has no title key", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/title", body: "{}"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("returns 400 when body has no sessionId key", () async {
      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/title",
          body: jsonEncode({"title": "New Title"}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("returns 200 with mapped Session JSON", () async {
      plugin.renameSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: "parent-1",
        title: "Renamed Session",
        time: PluginSessionTime(created: 10, updated: 20, archived: 30),
        summary: PluginSessionSummary(additions: 4, deletions: 1, files: 2),
      );

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/title",
          body: jsonEncode(const RenameSessionRequest(sessionId: "s1", title: "Renamed Session").toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final session = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(session["id"], equals("s1"));
      expect(session["projectID"], equals("p1"));
      expect(session["directory"], equals("/tmp"));
      expect(session["parentID"], equals("parent-1"));
      expect(session["title"], equals("Renamed Session"));
    });

    test("returns 400 on malformed body", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/title", body: "not-json"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });
  });
}
