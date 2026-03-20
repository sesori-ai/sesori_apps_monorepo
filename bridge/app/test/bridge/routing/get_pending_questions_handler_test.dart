import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_pending_questions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetPendingQuestionsHandler", () {
    late FakeBridgePlugin plugin;
    late GetPendingQuestionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetPendingQuestionsHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /question", () {
      expect(handler.canHandle(makeRequest("GET", "/question")), isTrue);
    });

    test("returns JSON list", () async {
      final response = await handler.handle(
        makeRequest("GET", "/question"),
        pathParams: {},
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
        makeRequest("GET", "/question"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final item = body[0] as Map<String, dynamic>;
      expect(item["id"], equals("q-1"));
      expect(item["sessionID"], equals("s-1"));

      final questions = item["questions"] as List<dynamic>;
      final question = questions[0] as Map<String, dynamic>;
      expect(question["question"], equals("Pick a tool"));
      expect(question["header"], equals("Tools"));
      expect(question["multiple"], isTrue);
      expect(question["custom"], isFalse);

      final options = question["options"] as List<dynamic>;
      final first = options[0] as Map<String, dynamic>;
      expect(first["label"], equals("A"));
      expect(first["description"], equals("Option A"));
      final second = options[1] as Map<String, dynamic>;
      expect(second["label"], equals("B"));
      expect(second["description"], equals("Option B"));
    });
  });
}
