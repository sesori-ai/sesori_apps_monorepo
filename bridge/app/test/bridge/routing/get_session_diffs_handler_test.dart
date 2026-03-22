import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_session_diffs_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetSessionDiffsHandler", () {
    late FakeBridgePlugin plugin;
    late GetSessionDiffsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetSessionDiffsHandler(plugin);
    });

    tearDown(() => plugin.close());

    // ── canHandle ────────────────────────────────────────────────────────────

    test("canHandle GET /session/:id/diff", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc123/diff")),
        isTrue,
      );
    });

    test("does not handle POST /session/:id/diff", () {
      expect(
        handler.canHandle(makeRequest("POST", "/session/abc123/diff")),
        isFalse,
      );
    });

    test("does not handle GET /session (wrong path)", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("does not handle GET /session/:id/message (different suffix)", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc/message")),
        isFalse,
      );
    });

    test("does not handle GET /session/:id/message/:msgId/diff (too many segments)", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc/message/msg1/diff")),
        isFalse,
      );
    });

    // ── 400 error cases ──────────────────────────────────────────────────────

    test("returns 400 when session id is missing from pathParams", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session//diff"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(400));
      expect(response.body, contains("missing session id"));
    });

    // ── Success cases ────────────────────────────────────────────────────────

    test("passes session id to plugin.getSessionDiffs", () async {
      await handler.handle(
        makeRequest("GET", "/session/session-xyz/diff"),
        pathParams: {"id": "session-xyz"},
        queryParams: {},
      );
      expect(plugin.lastGetSessionDiffsSessionId, equals("session-xyz"));
    });

    test("returns 200 with application/json content-type", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("returns empty JSON array when plugin has no diffs", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );
      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body, isEmpty);
    });

    test("maps PluginFileDiff fields to FileDiff", () async {
      plugin.sessionDiffsResult = [
        const PluginFileDiff(
          file: "lib/main.dart",
          before: "old content",
          after: "new content",
          additions: 10,
          deletions: 3,
          status: "modified",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(1));
      final diff = body[0] as Map<String, dynamic>;
      expect(diff["file"], equals("lib/main.dart"));
      expect(diff["before"], equals("old content"));
      expect(diff["after"], equals("new content"));
      expect(diff["additions"], equals(10));
      expect(diff["deletions"], equals(3));
      expect(diff["status"], equals("modified"));
    });

    test("maps status: added correctly", () async {
      plugin.sessionDiffsResult = [
        const PluginFileDiff(
          file: "new_file.dart",
          before: "",
          after: "content",
          additions: 5,
          deletions: 0,
          status: "added",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final diff = body[0] as Map<String, dynamic>;
      expect(diff["status"], equals("added"));
    });

    test("maps status: deleted correctly", () async {
      plugin.sessionDiffsResult = [
        const PluginFileDiff(
          file: "deleted_file.dart",
          before: "content",
          after: "",
          additions: 0,
          deletions: 8,
          status: "deleted",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final diff = body[0] as Map<String, dynamic>;
      expect(diff["status"], equals("deleted"));
    });

    test("maps null status to null in response", () async {
      plugin.sessionDiffsResult = [
        const PluginFileDiff(
          file: "file.dart",
          before: "before",
          after: "after",
          additions: 1,
          deletions: 1,
          status: null,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final diff = body[0] as Map<String, dynamic>;
      expect(diff["status"], isNull);
    });

    test("returns multiple diffs", () async {
      plugin.sessionDiffsResult = [
        const PluginFileDiff(
          file: "file1.dart",
          before: "a",
          after: "b",
          additions: 1,
          deletions: 0,
          status: "modified",
        ),
        const PluginFileDiff(
          file: "file2.dart",
          before: "",
          after: "new",
          additions: 3,
          deletions: 0,
          status: "added",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(2));
    });

    test("re-throws exception from plugin so router can produce error response", () async {
      plugin.throwOnGetSessionDiffs = true;

      expect(
        () => handler.handle(
          makeRequest("GET", "/session/s1/diff"),
          pathParams: {"id": "s1"},
          queryParams: {},
        ),
        throwsException,
      );
    });
  });
}
