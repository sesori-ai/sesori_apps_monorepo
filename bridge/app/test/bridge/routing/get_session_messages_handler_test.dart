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

    test("canHandle POST /session/messages", () {
      expect(handler.canHandle(makeRequest("POST", "/session/messages")), isTrue);
    });

    test("does not handle GET /session/messages", () {
      expect(handler.canHandle(makeRequest("GET", "/session/messages")), isFalse);
    });

    test("does not handle POST /session (wrong path)", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("returns 400 when session id is empty", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/session/messages", body: jsonEncode({"sessionId": ""})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
      expect(response.body, contains("empty session id"));
    });

    test("uses request body sessionId as the session ID passed to plugin", () async {
      await handler.handleInternal(
        makeRequest("POST", "/session/messages", body: jsonEncode({"sessionId": "session-xyz"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetMessagesSessionId, equals("session-xyz"));
    });

    test("returns 200 with application/json content-type", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/session/messages", body: jsonEncode({"sessionId": "s1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("returns empty list when plugin has no messages", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/session/messages", body: jsonEncode({"sessionId": "s1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      final json = jsonDecode(response.body!) as Map<String, dynamic>;
      final body = json["messages"] as List<dynamic>;
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

      final response = await handler.handleInternal(
        makeRequest("POST", "/session/messages", body: jsonEncode({"sessionId": "s1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final json = jsonDecode(response.body!) as Map<String, dynamic>;
      final body = json["messages"] as List<dynamic>;
      expect(body.length, equals(2));
    });
  });
}
