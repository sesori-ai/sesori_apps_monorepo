import "package:sesori_bridge/src/routing/get_session_messages_through_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionMessagesThroughHandler", () {
    late GetSessionMessagesThroughHandler handler;

    setUp(() {
      handler = GetSessionMessagesThroughHandler(chatHistoryService: createTestChatHistory().service);
    });

    SessionMessagesThroughRequest request({required String sessionId, required int throughSeq, required int before}) =>
        SessionMessagesThroughRequest(
          sessionId: sessionId,
          throughSeq: throughSeq,
          before: before,
          attachmentDelivery: MessageAttachmentDelivery.storedReference,
          storedOnly: true,
          toolOutputDelivery: ToolOutputDelivery.inline,
        );

    test("handles POST /session/messages/through only", () {
      expect(handler.canHandle(makeRequest("POST", "/session/messages/through")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/session/messages/through")), isFalse);
      expect(handler.canHandle(makeRequest("POST", "/session/messages")), isFalse);
    });

    test("returns 400 unless throughSeq is lower than before", () async {
      for (final throughSeq in const [5, 6]) {
        await expectLater(
          () => handler.handle(
            makeRequest("POST", "/session/messages/through"),
            body: request(sessionId: "s1", throughSeq: throughSeq, before: 5),
          ),
          throwsA(isA<RelayResponse>().having((response) => response.status, "status", 400)),
        );
      }
    });

    test("returns 400 when the session id is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/messages/through"),
          body: request(sessionId: "", throughSeq: 1, before: 5),
        ),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 400)),
      );
    });

    test("the request round-trips", () {
      final body = request(sessionId: "s1", throughSeq: 3, before: 9);

      expect(SessionMessagesThroughRequest.fromJson(body.toJson()), body);
    });
  });
}
