import "package:sesori_bridge/src/bridge/routing/get_session_questions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetSessionQuestionsHandler", () {
    late FakeBridgePlugin plugin;
    late GetSessionQuestionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetSessionQuestionsHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /session/questions", () {
      expect(handler.canHandle(makeRequest("POST", "/session/questions")), isTrue);
    });

    test("does not handle GET /session/questions", () {
      expect(handler.canHandle(makeRequest("GET", "/session/questions")), isFalse);
    });

    test("returns 400 when session id is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/questions"),
          body: const SessionIdRequest(sessionId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns typed response", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/questions"),
        body: const SessionIdRequest(sessionId: "s-1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.data, isA<List<PendingQuestion>>());
    });

    test("maps fields including nested question info and options", () async {
      plugin.pendingQuestionsResult = [
        const PluginPendingQuestion(
          id: "q-1",
          sessionID: "s-1",
          questions: [
            PluginQuestionInfo(
              question: "Pick a tool",
              header: "Tools",
              options: [
                PluginQuestionOption(label: "A", description: "Option A"),
                PluginQuestionOption(label: "B", description: "Option B"),
              ],
              multiple: true,
              custom: false,
            ),
          ],
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/session/questions"),
        body: const SessionIdRequest(sessionId: "s-1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final item = response.data.first;
      expect(item.id, equals("q-1"));
      expect(item.sessionID, equals("s-1"));

      final question = item.questions.first;
      expect(question.question, equals("Pick a tool"));
      expect(question.header, equals("Tools"));
      expect(question.multiple, isTrue);
      expect(question.custom, isFalse);

      final first = question.options[0];
      expect(first.label, equals("A"));
      expect(first.description, equals("Option A"));
      final second = question.options[1];
      expect(second.label, equals("B"));
      expect(second.description, equals("Option B"));
    });
  });
}
