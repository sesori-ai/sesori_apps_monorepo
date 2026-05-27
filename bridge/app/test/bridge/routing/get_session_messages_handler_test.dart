import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge/src/bridge/api/codex_defaults_api.dart";
import "package:sesori_bridge/src/bridge/repositories/message_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_messages_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetSessionMessagesHandler", () {
    late FakeBridgePlugin plugin;
    late GetSessionMessagesHandler handler;
    late Directory codexHome;

    setUp(() {
      plugin = FakeBridgePlugin();
      codexHome = Directory.systemTemp.createTempSync("codex-home-messages-");
      handler = GetSessionMessagesHandler(
        MessageRepository(
          plugin: plugin,
          codexDefaultsApi: CodexDefaultsApi(environment: {"CODEX_HOME": codexHome.path}),
        ),
      );
    });

    tearDown(() {
      plugin.close();
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {}
    });

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
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/messages"),
          body: const SessionIdRequest(sessionId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("uses request body sessionId as the session ID passed to plugin", () async {
      await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionIdRequest(sessionId: "session-xyz"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetMessagesSessionId, equals("session-xyz"));
    });

    test("returns typed response", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response, isA<MessageWithPartsResponse>());
    });

    test("returns empty list when plugin has no messages", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.messages, isEmpty);
    });

    test("returns serialised message list", () async {
      plugin.messagesResult = [
        const PluginMessageWithParts(
          info: PluginMessage.user(
            id: "m1",
            sessionID: "s1",
            agent: null,
          ),
          parts: [],
        ),
        const PluginMessageWithParts(
          info: PluginMessage.assistant(
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
        makeRequest("POST", "/session/messages"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.messages.length, equals(2));
    });

    test("fills missing Codex assistant agent and model defaults", () async {
      plugin.pluginId = "codex";
      _writeCodexDefaults(codexHome);
      plugin.messagesResult = [
        const PluginMessageWithParts(
          info: PluginMessage.assistant(
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
        makeRequest("POST", "/session/messages"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(
        response.messages.single.info,
        equals(
          const Message.assistant(
            id: "m2",
            sessionID: "s1",
            agent: "codex",
            modelID: "gpt-5.4",
            providerID: "openai",
          ),
        ),
      );
    });

    test("handleInternal returns 502 for upstream incompatibility", () async {
      plugin.throwOnGetMessagesError = PluginApiException("GET /session/s1/message", 502);

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/messages",
          body: jsonEncode(const SessionIdRequest(sessionId: "s1").toJson()),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(502));
      expect(response.body, contains("PluginApiException"));
    });
  });
}

void _writeCodexDefaults(Directory codexHome) {
  File(p.join(codexHome.path, "config.toml")).writeAsStringSync('model = "gpt-5.4"');
  final rollout = File(
    p.join(
      codexHome.path,
      "sessions/2026/05/27/rollout-2026-05-27T10-00-00-s1.jsonl",
    ),
  )..createSync(recursive: true);
  rollout.writeAsStringSync(
    '{"timestamp":"2026-05-27T10:00:00Z","type":"session_meta","payload":{"id":"s1","timestamp":"2026-05-27T10:00:00Z","cwd":"/repo","model_provider":"openai"}}\n',
  );
}
