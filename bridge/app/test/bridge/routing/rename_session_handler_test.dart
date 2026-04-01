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

    test("extracts sessionId and title from typed body", () async {
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
        makeRequest("PATCH", "/session/title"),
        body: const RenameSessionRequest(sessionId: "s1", title: "New Title"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastRenameSessionId, equals("s1"));
      expect(plugin.lastRenameSessionTitle, equals("New Title"));
    });

    test("returns mapped Session", () async {
      plugin.renameSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: "parent-1",
        title: "Renamed Session",
        time: PluginSessionTime(created: 10, updated: 20, archived: 30),
        summary: PluginSessionSummary(additions: 4, deletions: 1, files: 2),
      );

      final result = await handler.handle(
        makeRequest("PATCH", "/session/title"),
        body: const RenameSessionRequest(sessionId: "s1", title: "Renamed Session"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      expect(result.projectID, equals("p1"));
      expect(result.directory, equals("/tmp"));
      expect(result.parentID, equals("parent-1"));
      expect(result.title, equals("Renamed Session"));
      expect(result.time?.created, equals(10));
      expect(result.time?.updated, equals(20));
      expect(result.time?.archived, equals(30));
      expect(result.summary?.additions, equals(4));
      expect(result.summary?.deletions, equals(1));
      expect(result.summary?.files, equals(2));
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("PATCH", "/session/title"),
          body: const RenameSessionRequest(sessionId: "", title: "New Title"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
