import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/update_session_archive_status_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("UpdateSessionArchiveStatusHandler", () {
    late FakeBridgePlugin plugin;
    late UpdateSessionArchiveStatusHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = UpdateSessionArchiveStatusHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle PATCH /session/:id", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/s1")), isTrue);
    });

    test("does not handle GET /session/:id", () {
      expect(handler.canHandle(makeRequest("GET", "/session/s1")), isFalse);
    });

    test("extracts id from pathParams", () async {
      plugin.updateSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: null,
        summary: null,
      );

      await handler.handle(
        makeRequest("PATCH", "/session/s1", body: '{"time":{"archived":123}}'),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastUpdateSessionId, equals("s1"));
    });

    test("parses archived int from body", () async {
      plugin.updateSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: PluginSessionTime(created: 1, updated: 2, archived: 123),
        summary: null,
      );

      await handler.handle(
        makeRequest("PATCH", "/session/s1", body: '{"time":{"archived":123}}'),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastUpdateSessionArchivedAt, equals(123));
    });

    test("parses archived null from body", () async {
      plugin.updateSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: PluginSessionTime(created: 1, updated: 2, archived: null),
        summary: null,
      );

      await handler.handle(
        makeRequest("PATCH", "/session/s1", body: '{"time":{"archived":null}}'),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastUpdateSessionArchivedAt, isNull);
    });

    test("returns 400 when body has no time key", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/s1", body: "{}"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("missing time.archived in body"));
    });

    test("returns 400 when time has no archived key", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/s1", body: '{"time":{}}'),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("missing time.archived in body"));
    });

    test("returns 200 with mapped Session JSON", () async {
      plugin.updateSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: "parent-1",
        title: "Updated Session",
        time: PluginSessionTime(created: 10, updated: 20, archived: 30),
        summary: PluginSessionSummary(additions: 4, deletions: 1, files: 2),
      );

      final response = await handler.handle(
        makeRequest("PATCH", "/session/s1", body: '{"time":{"archived":30}}'),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final session = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(session["id"], equals("s1"));
      expect(session["projectID"], equals("p1"));
      expect(session["directory"], equals("/tmp"));
      expect(session["parentID"], equals("parent-1"));
      expect(session["title"], equals("Updated Session"));
    });

    test("returns 400 on malformed body", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/s1", body: "not-json"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });
  });
}
