import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_project_questions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetProjectQuestionsHandler", () {
    late FakeBridgePlugin plugin;
    late GetProjectQuestionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetProjectQuestionsHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /project/questions", () {
      expect(handler.canHandle(makeRequest("POST", "/project/questions")), isTrue);
    });

    test("does not handle GET /project/questions", () {
      expect(handler.canHandle(makeRequest("GET", "/project/questions")), isFalse);
    });

    test("returns JSON object on success", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/project/questions", body: jsonEncode({"projectId": "/tmp/project"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(body["data"], isA<List<dynamic>>());
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

      final response = await handler.handleInternal(
        makeRequest("POST", "/project/questions", body: jsonEncode({"projectId": "/tmp/project"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final json = jsonDecode(response.body!) as Map<String, dynamic>;
      final body = json["data"] as List<dynamic>;
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
