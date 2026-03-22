import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_message_diffs_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetMessageDiffsHandler", () {
    late FakeBridgePlugin plugin;
    late GetMessageDiffsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetMessageDiffsHandler(plugin);
    });

    tearDown(() => plugin.close());

    // ── canHandle ────────────────────────────────────────────────────────────

    test("canHandle GET /session/:id/message/:messageId/diff", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc/message/msg1/diff")),
        isTrue,
      );
    });

    test("does not handle POST /session/:id/message/:messageId/diff", () {
      expect(
        handler.canHandle(makeRequest("POST", "/session/abc/message/msg1/diff")),
        isFalse,
      );
    });

    test("does not handle GET /session/:id/diff (session-level path)", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc/diff")),
        isFalse,
      );
    });

    test("does not handle GET /session/:id/message (missing suffix)", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc/message")),
        isFalse,
      );
    });

    test("does not handle GET /session/:id/message/:msgId (no trailing /diff)", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc/message/msg1")),
        isFalse,
      );
    });

    // ── 400 error cases ──────────────────────────────────────────────────────

    test("returns 400 when session id is missing from pathParams", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session//message/msg1/diff"),
        pathParams: {"messageId": "msg1"},
        queryParams: {},
      );
      expect(response.status, equals(400));
      expect(response.body, contains("missing session id"));
    });

    test("returns 400 when message id is missing from pathParams", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message//diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );
      expect(response.status, equals(400));
      expect(response.body, contains("missing message id"));
    });

    // ── Success cases ────────────────────────────────────────────────────────

    test("passes session id and message id to plugin.getMessageDiffs", () async {
      await handler.handle(
        makeRequest("GET", "/session/session-xyz/message/msg-abc/diff"),
        pathParams: {"id": "session-xyz", "messageId": "msg-abc"},
        queryParams: {},
      );
      expect(plugin.lastGetMessageDiffsSessionId, equals("session-xyz"));
      expect(plugin.lastGetMessageDiffsMessageId, equals("msg-abc"));
    });

    test("returns 200 with application/json content-type", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message/m1/diff"),
        pathParams: {"id": "s1", "messageId": "m1"},
        queryParams: {},
      );
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("returns empty JSON array when plugin has no diffs", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message/m1/diff"),
        pathParams: {"id": "s1", "messageId": "m1"},
        queryParams: {},
      );
      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body, isEmpty);
    });

    test("maps PluginFileDiff fields to FileDiff", () async {
      plugin.messageDiffsResult = [
        const PluginFileDiff(
          file: "lib/feature.dart",
          before: "before content",
          after: "after content",
          additions: 7,
          deletions: 2,
          status: "modified",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message/m1/diff"),
        pathParams: {"id": "s1", "messageId": "m1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(1));
      final diff = body[0] as Map<String, dynamic>;
      expect(diff["file"], equals("lib/feature.dart"));
      expect(diff["before"], equals("before content"));
      expect(diff["after"], equals("after content"));
      expect(diff["additions"], equals(7));
      expect(diff["deletions"], equals(2));
      expect(diff["status"], equals("modified"));
    });

    test("maps status: added correctly", () async {
      plugin.messageDiffsResult = [
        const PluginFileDiff(
          file: "new.dart",
          before: "",
          after: "content",
          additions: 4,
          deletions: 0,
          status: "added",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message/m1/diff"),
        pathParams: {"id": "s1", "messageId": "m1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect((body[0] as Map<String, dynamic>)["status"], equals("added"));
    });

    test("maps status: deleted correctly", () async {
      plugin.messageDiffsResult = [
        const PluginFileDiff(
          file: "gone.dart",
          before: "content",
          after: "",
          additions: 0,
          deletions: 6,
          status: "deleted",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message/m1/diff"),
        pathParams: {"id": "s1", "messageId": "m1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect((body[0] as Map<String, dynamic>)["status"], equals("deleted"));
    });

    test("maps null status to null in response", () async {
      plugin.messageDiffsResult = [
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
        makeRequest("GET", "/session/s1/message/m1/diff"),
        pathParams: {"id": "s1", "messageId": "m1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect((body[0] as Map<String, dynamic>)["status"], isNull);
    });

    test("returns multiple diffs", () async {
      plugin.messageDiffsResult = [
        const PluginFileDiff(
          file: "a.dart",
          before: "x",
          after: "y",
          additions: 1,
          deletions: 1,
          status: "modified",
        ),
        const PluginFileDiff(
          file: "b.dart",
          before: "",
          after: "new",
          additions: 2,
          deletions: 0,
          status: "added",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message/m1/diff"),
        pathParams: {"id": "s1", "messageId": "m1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(2));
    });

    test("re-throws exception from plugin so router can produce error response", () async {
      plugin.throwOnGetMessageDiffs = true;

      expect(
        () => handler.handle(
          makeRequest("GET", "/session/s1/message/m1/diff"),
          pathParams: {"id": "s1", "messageId": "m1"},
          queryParams: {},
        ),
        throwsException,
      );
    });
  });
}
