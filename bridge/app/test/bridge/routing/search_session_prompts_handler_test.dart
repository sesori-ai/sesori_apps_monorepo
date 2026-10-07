import "package:sesori_bridge/src/routing/search_session_prompts_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "routing_test_helpers.dart";

void main() {
  group("SearchSessionPromptsHandler", () {
    late SearchSessionPromptsHandler handler;

    setUp(() {
      handler = SearchSessionPromptsHandler(chatHistoryService: createTestChatHistory().service);
    });

    test("handles POST /session/prompts/search only", () {
      expect(handler.canHandle(makeRequest("POST", "/session/prompts/search")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/session/prompts/search")), isFalse);
      expect(handler.canHandle(makeRequest("POST", "/session/prompts")), isFalse);
    });

    test("answers an unknown session with no matches, never a 404", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/prompts/search"),
        body: const SessionPromptSearchRequest(sessionId: "unknown", query: "build"),
      );

      expect(response, const SessionPromptSearchResponse(matches: []));
    });

    test("returns 400 when the session id is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/prompts/search"),
          body: const SessionPromptSearchRequest(sessionId: "", query: "build"),
        ),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 400)),
      );
    });
  });
}
