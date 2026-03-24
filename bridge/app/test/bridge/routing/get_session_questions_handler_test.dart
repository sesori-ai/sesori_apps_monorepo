import "dart:convert";

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

    test("canHandle GET /session/:id/questions", () {
      expect(handler.canHandle(makeRequest("GET", "/session/s-1/questions")), isTrue);
    });

    test("rejects GET /session/questions (missing id segment)", () {
      expect(handler.canHandle(makeRequest("GET", "/session/questions")), isFalse);
    });

    test("returns 400 when session id is missing", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session//questions"),
        pathParams: {"id": ""},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("missing session id"));
    });

    test("returns JSON list", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/s-1/questions"),
        pathParams: {"id": "s-1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      expect(jsonDecode(response.body!), isA<List<dynamic>>());
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
        makeRequest("GET", "/session/s-1/questions"),
        pathParams: {"id": "s-1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final questions = body.map((q) => PendingQuestion.fromJson(q as Map<String, dynamic>)).toList();

      final item = questions.first;
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
