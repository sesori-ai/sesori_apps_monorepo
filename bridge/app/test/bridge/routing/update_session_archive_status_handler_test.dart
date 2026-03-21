import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/update_session_archive_status_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
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
        makeRequest(
          "PATCH",
          "/session/s1",
          body: jsonEncode(
            const UpdateSessionArchiveRequest(archived: true).toJson(),
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastUpdateSessionId, equals("s1"));
    });

    test("parses archived=true from body", () async {
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
        makeRequest(
          "PATCH",
          "/session/s1",
          body: jsonEncode(
            const UpdateSessionArchiveRequest(archived: true).toJson(),
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastUpdateSessionArchived, isTrue);
    });

    test("parses archived=false from body", () async {
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
        makeRequest(
          "PATCH",
          "/session/s1",
          body: jsonEncode(
            const UpdateSessionArchiveRequest(archived: false).toJson(),
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastUpdateSessionArchived, isFalse);
    });

    test("returns 400 when body has no archived key", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/s1", body: "{}"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("returns 400 when path param id is missing", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/s1", body: '{"archived":true}'),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("missing session id"));
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
        makeRequest(
          "PATCH",
          "/session/s1",
          body: jsonEncode(
            const UpdateSessionArchiveRequest(archived: true).toJson(),
          ),
        ),
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
