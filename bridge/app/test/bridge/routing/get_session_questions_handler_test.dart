import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/agent_page_repository.dart";
import "package:sesori_bridge/src/routing/get_session_questions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/agent_page_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionQuestionsHandler", () {
    late FakeBridgePlugin plugin;
    late GetSessionQuestionsHandler handler;
    late AppDatabase db;
    late AgentPageRepository pages;

    setUp(() async {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      addTearDown(db.close);
      await recordSessionBinding(
        database: db,
        sessionId: "s-1",
        backendSessionId: "backend-s-1",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: null,
      );
      handler = GetSessionQuestionsHandler(
        questionRepository: singlePluginQuestionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
        ),
        agentPageService: () {
          final agentPages = buildTestAgentPages(database: db, plugin: plugin);
          pages = agentPages.pages;
          addTearDown(pages.dispose);
          return agentPages.service;
        }(),
      );
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
          request: makeRequest("POST", "/session/questions"),
          body: const SessionIdRequest(sessionId: ""),
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns typed response", () async {
      final response = await handler.handle(
        request: makeRequest("POST", "/session/questions"),
        body: const SessionIdRequest(sessionId: "s-1"),
      );

      expect(response.data, isA<List<PendingQuestion>>());
    });

    test("maps fields including nested question info and options", () async {
      plugin.pendingQuestionsResult = [
        const PluginPendingQuestion(
          interactionKind: PluginQuestionInteractionKind.question,
          id: "q-1",
          sessionID: "backend-s-1",
          displaySessionId: null,
          questions: [
            PluginQuestionInfo(
              question: "Pick a tool",
              header: "Tools",
              options: [
                PluginQuestionOption(label: "A", description: "Option A", isDefault: false),
                PluginQuestionOption(label: "B", description: "Option B", isDefault: false),
              ],
              multiple: true,
              custom: false,
            ),
          ],
        ),
      ];

      final response = await handler.handle(
        request: makeRequest("POST", "/session/questions"),
        body: const SessionIdRequest(sessionId: "s-1"),
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

    test("lists pending pages as page markers after the plugin's questions", () async {
      plugin.pendingQuestionsResult = [
        const PluginPendingQuestion(
          interactionKind: PluginQuestionInteractionKind.question,
          id: "q-1",
          sessionID: "backend-s-1",
          displaySessionId: null,
          questions: [],
        ),
      ];
      final pageId = await addTestPage(pages: pages, sessionId: "s-1");

      final response = await handler.handle(
        request: makeRequest("POST", "/session/questions"),
        body: const SessionIdRequest(sessionId: "s-1"),
      );

      expect([for (final item in response.data) item.id], ["q-1", pageId]);
      final marker = response.data.last;
      expect(marker.interactionKind, QuestionInteractionKind.page);
      expect(marker.questions.single.header, "Release plan");
      expect(marker.questions.single.options.single.label, "Cancel");
    });

    test("leaves out the pages of an archived session", () async {
      await addTestPage(pages: pages, sessionId: "s-1");
      await db.sessionDao.setArchived(sessionId: "s-1", archivedAt: 7, updatedAt: 7, projectionUpdatedAt: 7);

      final response = await handler.handle(
        request: makeRequest("POST", "/session/questions"),
        body: const SessionIdRequest(sessionId: "s-1"),
      );

      expect(response.data, isEmpty);
    });
  });
}
