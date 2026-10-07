import "package:sesori_bridge/src/routing/get_session_prompt_index_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionPromptIndexHandler", () {
    late GetSessionPromptIndexHandler handler;

    setUp(() {
      handler = GetSessionPromptIndexHandler(chatHistoryService: createTestChatHistory().service);
    });

    test("handles POST /session/prompts only", () {
      expect(handler.canHandle(makeRequest("POST", "/session/prompts")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/session/prompts")), isFalse);
    });

    test("answers an unknown session with an empty list, never a 404", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/prompts"),
        body: const SessionIdRequest(sessionId: "unknown"),
      );

      expect(response, const SessionPromptIndexResponse(entries: []));
    });

    test("returns 400 when the session id is empty", () async {
      await expectLater(
        () => handler.handle(makeRequest("POST", "/session/prompts"), body: const SessionIdRequest(sessionId: "")),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 400)),
      );
    });
  });
}
