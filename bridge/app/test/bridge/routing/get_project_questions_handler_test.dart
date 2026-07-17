import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/question_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_project_questions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetProjectQuestionsHandler", () {
    late FakeBridgePlugin plugin;
    late GetProjectQuestionsHandler handler;
    late AppDatabase db;

    setUp(() async {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      addTearDown(db.close);
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/tmp/project"]);
      await recordSessionBinding(
        database: db,
        sessionId: "stable-s-1",
        backendSessionId: "s-1",
        pluginId: plugin.id,
        projectId: "/tmp/project",
        parentSessionId: null,
      );
      handler = GetProjectQuestionsHandler(
        questionRepository: QuestionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
        ),
      );
    });

    tearDown(() => plugin.close());

    test("canHandle POST /project/questions", () {
      expect(handler.canHandle(makeRequest("POST", "/project/questions")), isTrue);
    });

    test("does not handle GET /project/questions", () {
      expect(handler.canHandle(makeRequest("GET", "/project/questions")), isFalse);
    });

    test("returns typed response on success", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/questions"),
        body: const ProjectIdRequest(projectId: "/tmp/project"),
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
          displaySessionId: null,
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
        makeRequest("POST", "/project/questions"),
        body: const ProjectIdRequest(projectId: "/tmp/project"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final item = response.data.first;
      expect(item.id, equals("q-1"));
      expect(item.sessionID, equals("stable-s-1"));

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

    test("throws 400 on empty project id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/project/questions"),
          body: const ProjectIdRequest(projectId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
