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
      final repo = QuestionRepository(plugin: plugin, sessionDao: db.sessionDao);

      final questions = await repo.getProjectQuestions(projectId: parent);

      expect(questions.map((q) => q.id), contains("q-w1"));
      // It resolved the question by asking the worktree session, not the parent dir.
      expect(plugin.queriedSessionIds, contains("w1"));
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
      final repo = QuestionRepository(plugin: plugin, sessionDao: db.sessionDao);

      final questions = await repo.getProjectQuestions(projectId: parent);

      expect(questions, isEmpty);
      expect(plugin.queriedSessionIds, isNot(contains("s2")));
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
  });

  @override
  final String launchDirectory;

  final List<PluginSession> allSessions;
  final Map<String, List<PluginPendingQuestion>> questionsBySession;
  final List<String> queriedSessionIds = [];

  @override
  String get id => "codex";

  @override
  Future<List<PluginSession>> listAllSessions() async => allSessions;

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async {
    queriedSessionIds.add(sessionId);
    return questionsBySession[sessionId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
