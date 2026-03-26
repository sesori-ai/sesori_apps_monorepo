import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_session_messages_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetSessionMessagesHandler", () {
    late FakeBridgePlugin plugin;
    late GetSessionMessagesHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetSessionMessagesHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /session/:id/message", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc123/message")),
        isTrue,
      );
    });

    test("does not handle POST /session/:id/message", () {
      expect(
        handler.canHandle(makeRequest("POST", "/session/abc123/message")),
        isFalse,
      );
    });

    test("does not handle GET /session (no id or trailing segment)", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("does not handle GET /session/:id (missing /message)", () {
      expect(handler.canHandle(makeRequest("GET", "/session/abc123")), isFalse);
    });

    test("does not handle GET /session/:id/message/extra (too many segments)", () {
      expect(
        handler.canHandle(makeRequest("GET", "/session/abc/message/extra")),
        isFalse,
      );
    });

    test("uses pathParams[id] as the session ID passed to plugin", () async {
      await handler.handle(
        makeRequest("GET", "/session/session-xyz/message"),
        pathParams: {"id": "session-xyz"},
        queryParams: {},
      );
      expect(plugin.lastGetMessagesSessionId, equals("session-xyz"));
    });

    test("returns 200 with application/json content-type", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("returns empty list when plugin has no messages", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );
      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body, isEmpty);
    });

    test("returns serialised message list", () async {
      plugin.messagesResult = [
        const PluginMessageWithParts(
          info: PluginMessage(
            role: "user",
            id: "m1",
            sessionID: "s1",
            agent: null,
            modelID: null,
            providerID: null,
          ),
          parts: [],
        ),
        const PluginMessageWithParts(
          info: PluginMessage(
            role: "assistant",
            id: "m2",
            sessionID: "s1",
            agent: null,
            modelID: null,
            providerID: null,
          ),
          parts: [],
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/message"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(2));
    });
  });
}
