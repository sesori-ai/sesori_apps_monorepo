import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/question_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

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

    Future<void> recordWorktreeSession({
      required String parent,
      required String worktree,
      required String sessionId,
    }) async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);
      await db.sessionDao.insertSession(
        sessionId: sessionId,
        projectId: parent,
        isDedicated: true,
        createdAt: 1,
        worktreePath: worktree,
        branchName: "session-001",
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "codex",
      );
    }

    test("getProjectQuestions surfaces a question raised in a worktree session under its parent", () async {
      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      await recordWorktreeSession(parent: parent, worktree: worktree, sessionId: "w1");

      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: parent,
        allSessions: [
          _session(parent, id: "s1"),
          _session(worktree, id: "w1"),
        ],
        questionsBySession: {
          "w1": const [
            PluginPendingQuestion(
              id: "q-w1",
              sessionID: "w1",
              displaySessionId: null,
              questions: [
                PluginQuestionInfo(
                  question: "Run command?",
                  header: "Approval",
                  options: [PluginQuestionOption(label: "Yes", description: "Approve")],
                  multiple: false,
                  custom: false,
                ),
              ],
            ),
          ],
        },
      );
      final repo = QuestionRepository(plugin: plugin, sessionDao: db.sessionDao, projectsDao: db.projectsDao);

      final questions = await repo.getProjectQuestions(projectId: parent);

      expect(questions.map((q) => q.id), contains("q-w1"));
      // It resolved the question by asking the worktree session, not the parent dir.
      expect(plugin.queriedSessionIds, contains("w1"));
    });

    test("getProjectQuestions skips tombstoned sessions", () async {
      const parent = "/tmp/proj/alpha";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);
      // The backend still enumerates the deleted session (no session/delete):
      // its questions must not surface — and must not be queried at all.
      await db.sessionDao.insertSessionTombstone(backendSessionId: "gone", pluginId: "codex", deletedAt: 1);

      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: parent,
        allSessions: [
          _session(parent, id: "s1"),
          _session(parent, id: "gone"),
        ],
        questionsBySession: {
          "gone": const [
            PluginPendingQuestion(id: "q-gone", sessionID: "gone", displaySessionId: null, questions: []),
          ],
        },
        ownProjectQuestions: const [
          PluginPendingQuestion(id: "q-gone", sessionID: "gone", displaySessionId: null, questions: []),
        ],
      );
      final repo = QuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
      );

      final questions = await repo.getProjectQuestions(projectId: parent);

      expect(questions.map((q) => q.id), isNot(contains("q-gone")));
      expect(plugin.queriedSessionIds, isNot(contains("gone")));
    });

    test("getProjectQuestions surfaces a question from a session only the plugin's live scoping knows", () async {
      const parent = "/tmp/proj/alpha";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);

      // A freshly-created session may exist only in the backend's memory (not
      // yet flushed to disk), so it is absent from listAllSessions — only the
      // plugin's own project-scoped query can surface its question.
      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: parent,
        allSessions: [_session(parent, id: "s1")],
        questionsBySession: {
          "s1": const [
            PluginPendingQuestion(id: "q-s1", sessionID: "s1", displaySessionId: null, questions: []),
          ],
        },
        ownProjectQuestions: const [
          // Duplicated with the per-session aggregation — must appear once.
          PluginPendingQuestion(id: "q-s1", sessionID: "s1", displaySessionId: null, questions: []),
          // Known only to the plugin's live in-memory scoping.
          PluginPendingQuestion(id: "q-fresh", sessionID: "s-fresh", displaySessionId: null, questions: []),
        ],
      );
      final repo = QuestionRepository(plugin: plugin, sessionDao: db.sessionDao, projectsDao: db.projectsDao);

      final questions = await repo.getProjectQuestions(projectId: parent);

      expect(questions.map((q) => q.id).toSet(), {"q-s1", "q-fresh"});
      expect(questions, hasLength(2));
    });

    test("getProjectQuestions asks a stored-row session missing from listAllSessions", () async {
      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      // A fresh worktree session the bridge recorded under its parent, whose
      // rollout has not been flushed yet: the plugin cannot enumerate it and
      // its own project scoping keys it to the worktree cwd, so only the
      // stored attribution can reach its pending questions.
      await recordWorktreeSession(parent: parent, worktree: worktree, sessionId: "w-fresh");

      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: parent,
        allSessions: const [],
        questionsBySession: {
          "w-fresh": const [
            PluginPendingQuestion(id: "q-fresh", sessionID: "w-fresh", displaySessionId: null, questions: []),
          ],
        },
      );
      final repo = QuestionRepository(plugin: plugin, sessionDao: db.sessionDao, projectsDao: db.projectsDao);

      final questions = await repo.getProjectQuestions(projectId: parent);

      expect(questions.map((q) => q.id), contains("q-fresh"));
      expect(plugin.queriedSessionIds, contains("w-fresh"));
    });

    test("getProjectQuestions keeps distinct questions that reuse an id across sessions", () async {
      const parent = "/tmp/proj/alpha";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);

      // Question ids are only guaranteed unique within a session, so the merge
      // must key by session id + question id rather than question id alone.
      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: parent,
        allSessions: [
          _session(parent, id: "s1"),
          _session(parent, id: "s2"),
        ],
        questionsBySession: {
          "s1": const [
            PluginPendingQuestion(id: "q-1", sessionID: "s1", displaySessionId: null, questions: []),
          ],
          "s2": const [
            PluginPendingQuestion(id: "q-1", sessionID: "s2", displaySessionId: null, questions: []),
          ],
        },
      );
      final repo = QuestionRepository(plugin: plugin, sessionDao: db.sessionDao, projectsDao: db.projectsDao);

      final questions = await repo.getProjectQuestions(projectId: parent);

      expect(questions.map((q) => q.sessionID).toSet(), {"s1", "s2"});
      expect(questions, hasLength(2));
    });

    test("getProjectQuestions does not surface questions from a session in another project", () async {
      const parent = "/tmp/proj/alpha";
      const other = "/tmp/proj/beta";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent, other]);

      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: parent,
        allSessions: [
          _session(parent, id: "s1"),
          _session(other, id: "s2"),
        ],
        questionsBySession: {
          "s2": const [
            PluginPendingQuestion(id: "q-s2", sessionID: "s2", displaySessionId: null, questions: []),
          ],
        },
      );
      final repo = QuestionRepository(plugin: plugin, sessionDao: db.sessionDao, projectsDao: db.projectsDao);

      final questions = await repo.getProjectQuestions(projectId: parent);

      expect(questions, isEmpty);
      expect(plugin.queriedSessionIds, isNot(contains("s2")));
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
              id: "q-gone",
              sessionID: "gone",
              displaySessionId: null,
              questions: [],
            ),
          ],
        },
      );
      final repository = QuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
      );

      expect(await repository.getPendingQuestions(sessionId: "gone"), isEmpty);
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
              id: "deleted-child",
              sessionID: "gone-child",
              displaySessionId: "root",
              questions: [],
            ),
            PluginPendingQuestion(
              id: "deleted-root",
              sessionID: "live-child",
              displaySessionId: "gone-root",
              questions: [],
            ),
            PluginPendingQuestion(
              id: "visible",
              sessionID: "live-child",
              displaySessionId: "root",
              questions: [],
            ),
          ],
        },
      );
      final repository = QuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
      );

      final questions = await repository.getPendingQuestions(sessionId: "root");

      expect(questions.map((question) => question.id), ["visible"]);
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
              id: "q-stale",
              sessionID: "live-child",
              displaySessionId: "gone-root",
              questions: [],
            ),
          ],
        },
      );
      final repository = QuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
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
              id: "q-stale-child",
              sessionID: "gone-child",
              displaySessionId: "live-root",
              questions: [],
            ),
          ],
        },
      );
      final repository = QuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
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

    test("getProjectQuestions filters display tombstones from both aggregation paths", () async {
      const parent = "/repo";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone-root",
        pluginId: "codex",
        deletedAt: 1,
      );
      final plugin = _FakeDerivedQuestionPlugin(
        launchDirectory: parent,
        allSessions: [_session(parent, id: "s1")],
        questionsBySession: {
          "s1": const [
            PluginPendingQuestion(
              id: "aggregated",
              sessionID: "child-a",
              displaySessionId: "gone-root",
              questions: [],
            ),
          ],
        },
        ownProjectQuestions: const [
          PluginPendingQuestion(
            id: "own",
            sessionID: "child-b",
            displaySessionId: "gone-root",
            questions: [],
          ),
        ],
      );
      final repository = QuestionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
      );

      expect(await repository.getProjectQuestions(projectId: parent), isEmpty);
      expect(plugin.queriedSessionIds, contains("s1"));
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
  summary: null,
);

/// A derive-style plugin whose pending questions are keyed per session, so the
/// repository must resolve the project's sessions (worktree-aware) and ask each.
class _FakeDerivedQuestionPlugin implements BridgeDerivedProjectsPluginApi {
  _FakeDerivedQuestionPlugin({
    required this.launchDirectory,
    required this.allSessions,
    required this.questionsBySession,
    this.ownProjectQuestions = const [],
  });

  @override
  final String launchDirectory;

  final List<PluginSession> allSessions;
  final Map<String, List<PluginPendingQuestion>> questionsBySession;

  /// What the plugin's own project-scoped query returns — its live in-memory
  /// view, which can know sessions that `listAllSessions` (disk) does not yet.
  final List<PluginPendingQuestion> ownProjectQuestions;
  final List<String> queriedSessionIds = [];
  int questionMutationCalls = 0;

  @override
  String get id => "codex";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async => allSessions;

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async {
    queriedSessionIds.add(sessionId);
    return questionsBySession[sessionId] ?? const [];
  }

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => ownProjectQuestions;

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    questionMutationCalls++;
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    questionMutationCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
