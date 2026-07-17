import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_session_messages_handler.dart";
import "package:sesori_bridge/src/bridge/services/command_timeline_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetSessionMessagesHandler", () {
    late _FakeCommandTimelineService timelineService;
    late GetSessionMessagesHandler handler;

    setUp(() {
      timelineService = _FakeCommandTimelineService();
      handler = GetSessionMessagesHandler(
        commandTimelineService: timelineService,
      );
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
      expect(timelineService.lastSessionId, equals("session-xyz"));
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
      timelineService.messages = [
        const MessageWithParts(
          info: Message.user(
            id: "m1",
            sessionID: "s1",
            agent: null,
            time: null,
          ),
          parts: [],
        ),
        const MessageWithParts(
          info: Message.assistant(
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
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.messages.length, equals(2));
    });

    test("handleInternal returns 502 for upstream incompatibility", () async {
      timelineService.error = PluginApiException("GET /session/s1/message", 502);

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

class _FakeCommandTimelineService implements CommandTimelineService {
  String? lastSessionId;
  Object? error;
  List<MessageWithParts> messages = const [];

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    lastSessionId = sessionId;
    final failure = error;
    if (failure != null) throw failure;
    return messages;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
