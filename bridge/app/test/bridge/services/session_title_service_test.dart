import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_title_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionTitleService", () {
    late AppDatabase db;
    late SessionRepository repository;
    late SessionTitleService service;

    setUp(() {
      db = createTestDatabase();
      repository = SessionRepository(
        plugin: _FakeDerivedPlugin(),
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      service = SessionTitleService(sessionRepository: repository);
    });

    tearDown(() => db.close());

    Future<void> insertSession() async {
      await repository.insertStoredSession(
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
    }

    test("applies a title captured before the session row exists", () async {
      await service.captureTitle(sessionId: "s1", title: "Early title");
      await insertSession();

      await service.applyPendingTitle(sessionId: "s1");

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "Early title");
    });

    test("preserves an explicit null pending title", () async {
      await service.captureTitle(sessionId: "s1", title: null);
      await insertSession();
      await db.sessionDao.setTitle(sessionId: "s1", title: "stale");

      await service.applyPendingTitle(sessionId: "s1");

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, isNull);
    });

    test("deletion discards a pending title", () async {
      await service.captureTitle(sessionId: "s1", title: "stale");
      await service.deleteSession(sessionId: "s1");
      await insertSession();

      await service.applyPendingTitle(sessionId: "s1");

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, isNull);
    });
  });
}

class _FakeDerivedPlugin implements BridgeDerivedProjectsPluginApi {
  @override
  String get id => "codex";

  @override
  String get launchDirectory => "/repo";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async => const [];

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
