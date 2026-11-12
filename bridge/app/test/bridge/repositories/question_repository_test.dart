import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_derived_bridge_plugin.dart";
import "../../helpers/test_database.dart";

void main() {
  group("QuestionRepository (bridge-derived)", () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> recordSession({
      required String stableId,
      required String backendId,
      required String projectId,
      required String? parentStableId,
    }) async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
      if (parentStableId == null) {
        await db.sessionDao.insertSession(
          fastMode: false,
          sessionId: stableId,
          backendSessionId: backendId,
          projectId: projectId,
          isDedicated: false,
          createdAt: 1,
          worktreePath: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          pluginId: "codex",
        );
      } else {
        await db.sessionDao.insertObservedChild(
          sessionId: stableId,
          backendSessionId: backendId,
          projectId: projectId,
          parentSessionId: parentStableId,
          directory: projectId,
          catalogTitle: null,
          archivedAt: null,
          createdAt: 1,
          updatedAt: 1,
          projectionUpdatedAt: 1,
          pluginId: "codex",
        );
      }
    }

    test("preserves checkbox, custom, and omitted answer slots through the shared contract", () async {
      await recordSession(
        stableId: "stable-dialog",
        backendId: "dialog",
        projectId: "/repo",
        parentStableId: null,
      );
      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: "/repo",
        allSessions: [_session("/repo", id: "dialog")],
        questionsBySession: const {
          "dialog": [
            PluginPendingQuestion(
              interactionKind: PluginQuestionInteractionKind.question,
              id: "question-1",
              sessionID: "dialog",
              displaySessionId: null,
              questions: [
                PluginQuestionInfo(
                  question: "Choose targets",
                  header: "Targets",
                  options: [
                    PluginQuestionOption(label: "iOS", description: "iPhone", isDefault: false),
                    PluginQuestionOption(label: "Android", description: "Android phone", isDefault: false),
                  ],
                  multiple: true,
                  custom: false,
                ),
                PluginQuestionInfo(
                  question: "Other target",
                  header: "Other",
                  options: [],
                  multiple: false,
                  custom: true,
                ),
                PluginQuestionInfo(question: "Notes", header: "Notes", options: [], multiple: false, custom: true),
              ],
            ),
          ],
        },
      );
      final repository = singlePluginQuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
      );

      final pending = (await repository.getPendingQuestions(sessionId: "stable-dialog")).single;
      expect(pending.questions.map((question) => question.header), ["Targets", "Other", "Notes"]);
      expect(pending.questions[0].multiple, isTrue);
      expect(pending.questions[0].custom, isFalse);
      expect(pending.questions[0].options, const [
        QuestionOption(label: "iOS", description: "iPhone"),
        QuestionOption(label: "Android", description: "Android phone"),
      ]);
      expect(pending.questions[1].multiple, isFalse);
      expect(pending.questions[1].custom, isTrue);

      final request = ReplyToQuestionRequest.fromJson(
        ReplyToQuestionRequest(
          requestId: pending.id,
          sessionId: pending.sessionID,
          answers: const [
            ReplyAnswer(values: ["iOS", "Android"]),
            ReplyAnswer(values: ["iOS"]),
            ReplyAnswer(values: []),
          ],
        ).toJson(),
      );
      await repository.replyToQuestion(
        questionId: request.requestId,
        sessionId: request.sessionId,
        answers: request.answers,
      );

      expect(plugin.receivedAnswers, [
        ["iOS", "Android"],
        ["iOS"],
        const <String>[],
      ]);
    });

    test("getPendingQuestions skips a tombstoned derived session", () async {
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone",
        pluginId: "codex",
        deletedAt: 1,
      );
      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: "/repo",
        allSessions: const [],
        questionsBySession: {
          "gone": const [
            PluginPendingQuestion(
              interactionKind: PluginQuestionInteractionKind.question,
              id: "q-gone",
              sessionID: "gone",
              displaySessionId: null,
              questions: [],
            ),
          ],
        },
      );
      final repository = singlePluginQuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
      );

      await expectLater(
        repository.getPendingQuestions(sessionId: "gone"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(plugin.queriedSessionIds, isNot(contains("gone")));

      await expectLater(
        repository.replyToQuestion(questionId: "q-gone", sessionId: "gone", answers: const []),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      await expectLater(
        repository.rejectQuestion(questionId: "q-gone", sessionId: "gone"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
    });

    test("getPendingQuestions filters tombstoned child and displayed sessions", () async {
      await recordSession(
        stableId: "stable-root",
        backendId: "root",
        projectId: "/repo",
        parentStableId: null,
      );
      await recordSession(
        stableId: "stable-child",
        backendId: "live-child",
        projectId: "/repo",
        parentStableId: "stable-root",
      );
      for (final sessionId in ["gone-child", "gone-root"]) {
        await db.sessionDao.insertSessionTombstone(
          backendSessionId: sessionId,
          pluginId: "codex",
          deletedAt: 1,
        );
      }
      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: "/repo",
        allSessions: const [],
        questionsBySession: {
          "root": const [
            PluginPendingQuestion(
              interactionKind: PluginQuestionInteractionKind.question,
              id: "deleted-child",
              sessionID: "gone-child",
              displaySessionId: "root",
              questions: [],
            ),
            PluginPendingQuestion(
              interactionKind: PluginQuestionInteractionKind.question,
              id: "deleted-root",
              sessionID: "live-child",
              displaySessionId: "gone-root",
              questions: [],
            ),
            PluginPendingQuestion(
              interactionKind: PluginQuestionInteractionKind.question,
              id: "visible",
              sessionID: "live-child",
              displaySessionId: "root",
              questions: [],
            ),
          ],
        },
      );
      final repository = singlePluginQuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
      );

      final questions = await repository.getPendingQuestions(sessionId: "stable-root");

      expect(questions.map((question) => question.id), ["visible"]);
      expect(questions.single.sessionID, "stable-child");
      expect(questions.single.displaySessionId, "stable-root");
    });

    test("question mutations reject a tombstoned displayed root", () async {
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone-root",
        pluginId: "codex",
        deletedAt: 1,
      );
      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: "/repo",
        allSessions: const [],
        questionsBySession: {
          "live-child": const [
            PluginPendingQuestion(
              interactionKind: PluginQuestionInteractionKind.question,
              id: "q-stale",
              sessionID: "live-child",
              displaySessionId: "gone-root",
              questions: [],
            ),
          ],
        },
      );
      final repository = singlePluginQuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
      );

      await expectLater(
        repository.replyToQuestion(questionId: "q-stale", sessionId: "live-child", answers: const []),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      await expectLater(
        repository.rejectQuestion(questionId: "q-stale", sessionId: "live-child"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(plugin.questionMutationCalls, isZero);
    });

    test("question mutations reject a tombstoned owning descendant", () async {
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone-child",
        pluginId: "codex",
        deletedAt: 1,
      );
      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: "/repo",
        allSessions: const [],
        questionsBySession: {
          "live-root": const [
            PluginPendingQuestion(
              interactionKind: PluginQuestionInteractionKind.question,
              id: "q-stale-child",
              sessionID: "gone-child",
              displaySessionId: "live-root",
              questions: [],
            ),
          ],
        },
      );
      final repository = singlePluginQuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
      );

      await expectLater(
        repository.replyToQuestion(questionId: "q-stale-child", sessionId: "live-root", answers: const []),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      await expectLater(
        repository.rejectQuestion(questionId: "q-stale-child", sessionId: "live-root"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(plugin.questionMutationCalls, isZero);
    });
  });
}

PluginSession _session(String directory, {required String id}) => PluginSession(
  id: id,
  projectID: directory,
  directory: directory,
  parentID: null,
  title: null,
  time: const PluginSessionTime(created: 1, updated: 1, archived: null),
);

/// A derive-style plugin whose pending questions are keyed per session.
class _FakeDerivedQuestionPlugin({
  required super.launchDirectory,
  required super.allSessions,
  required final Map<String, List<PluginPendingQuestion>> questionsBySession,
}) extends FakeDerivedBridgePlugin {
  this : super(id: "codex");

  final List<String> queriedSessionIds = [];
  int questionMutationCalls = 0;
  List<List<String>>? receivedAnswers;

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async {
    queriedSessionIds.add(sessionId);
    return questionsBySession[sessionId] ?? const [];
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    questionMutationCalls++;
    receivedAnswers = answers;
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    questionMutationCalls++;
  }
}
