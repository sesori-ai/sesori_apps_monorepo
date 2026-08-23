import "dart:convert";

import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/routing/get_session_messages_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionMessagesHandler", () {
    late FakeBridgePlugin plugin;
    late TestChatHistory history;
    late GetSessionMessagesHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      history = createTestChatHistory(
        sessionRepository: _MessageSessionRepository(plugin: plugin),
      );
      handler = GetSessionMessagesHandler(
        chatHistoryService: history.service,
      );
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

    test("returns 400 for a non-positive limit", () async {
      for (final limit in const [0, -1]) {
        await expectLater(
          () => handler.handle(
            makeRequest("POST", "/session/messages"),
            body: SessionMessagesRequest(sessionId: "session-1", limit: limit, before: null),
          ),
          throwsA(isA<RelayResponse>().having((response) => response.status, "status", 400)),
        );
      }
    });

    test("returns 400 when session id is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/messages"),
          body: const SessionMessagesRequest(sessionId: "", limit: null, before: null),
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("uses request body sessionId as the session ID passed to plugin", () async {
      await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionMessagesRequest(sessionId: "session-xyz", limit: null, before: null),
      );
      expect(plugin.lastGetMessagesSessionId, equals("session-xyz"));
    });

    test("returns typed response", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionMessagesRequest(sessionId: "s1", limit: null, before: null),
      );
      expect(response, isA<MessageWithPartsResponse>());
    });

    test("returns empty list when plugin has no messages", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionMessagesRequest(sessionId: "s1", limit: null, before: null),
      );
      expect(response.messages, isEmpty);
    });

    test("returns serialised message list", () async {
      plugin.messagesResult = [
        const PluginMessageWithParts(
          info: PluginMessage.user(
            promptId: null,
            id: "m1",
            sessionID: "s1",
            agent: null,
            time: null,
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
            time: null,
          ),
          parts: [],
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionMessagesRequest(sessionId: "s1", limit: null, before: null),
      );

      expect(response.messages.length, equals(2));
    });

    test("keeps default delivery inline and threads explicit stored references", () async {
      plugin.messagesResult = [
        PluginMessageWithParts(
          info: const PluginMessage.user(
            promptId: null,
            id: "m1",
            sessionID: "s1",
            agent: null,
            time: null,
          ),
          parts: [
            PluginMessagePart(
              id: "p1",
              sessionID: "s1",
              messageID: "m1",
              type: PluginMessagePartType.file,
              text: null,
              tool: null,
              state: null,
              prompt: null,
              description: null,
              agent: null,
              agentName: null,
              attempt: null,
              retryError: null,
              attachment: PluginMessageAttachment.inlineImage(
                mime: "image/png",
                base64: base64Encode(const [1, 2, 3]),
                filename: "shot.png",
              ),
            ),
          ],
        ),
      ];

      final inlineResponse = await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionMessagesRequest(sessionId: "s1", limit: null, before: null),
      );
      expect(inlineResponse.messages.single.parts.single.attachment, isA<MessageAttachmentInlineImage>());

      final response = await handler.handle(
        makeRequest("POST", "/session/messages"),
        body: const SessionMessagesRequest(
          sessionId: "s1",
          limit: null,
          before: null,
          attachmentDelivery: MessageAttachmentDelivery.storedReference,
        ),
      );

      expect(
        response.messages.single.parts.single.attachment,
        isA<MessageAttachmentStoredImage>().having((image) => image.bridgeId, "bridgeId", "br_test1234"),
      );
    });

    test("handleInternal returns 502 for upstream incompatibility", () async {
      plugin.throwOnGetMessagesError = PluginApiException("GET /session/s1/message", 502);

      final response = await handler.routeForTest(
        makeRequest(
          "POST",
          "/session/messages",
          body: jsonEncode(const SessionMessagesRequest(sessionId: "s1", limit: null, before: null).toJson()),
        ),
      );

      expect(response.status, equals(502));
      expect(response.body, contains("PluginApiException"));
    });
  });
}

class _MessageSessionRepository({required super.plugin}) extends FakeSessionRepository {
  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async => StoredSession(
    id: sessionId,
    backendSessionId: sessionId,
    pluginId: "fake",
    projectId: "project-1",
    parentSessionId: null,
    directory: "/tmp/project-1",
    worktreePath: null,
    branchName: null,
    isDedicated: false,
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
  );
}
