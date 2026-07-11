import "dart:async";

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
    late _FakeDerivedPlugin plugin;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeDerivedPlugin();
      repository = SessionRepository(
        plugin: plugin,
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

    test("buffers a rename until its session row exists", () async {
      final renamed = await service.renameSession(sessionId: "s1", title: "User rename");
      expect(renamed.title, "User rename");
      await insertSession();

      await service.applyPendingTitle(sessionId: "s1");

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "User rename");
    });

    test("applies a pending null by removing the stored title copy", () async {
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

    test("a rename waits for deletion and cannot reach the plugin afterward", () async {
      final deleteStarted = Completer<void>();
      final releaseDelete = Completer<void>();
      plugin
        ..deleteStarted = deleteStarted
        ..releaseDelete = releaseDelete.future;

      final deletion = service.deleteSession(sessionId: "s1");
      await deleteStarted.future;
      final rename = service.renameSession(sessionId: "s1", title: "Resurrected");
      await Future<void>.delayed(Duration.zero);
      expect(plugin.renameCalls, isZero);

      releaseDelete.complete();
      await deletion;
      await expectLater(
        rename,
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(plugin.renameCalls, isZero);
    });
  });
}

class _FakeDerivedPlugin implements BridgeDerivedProjectsPluginApi {
  Completer<void>? deleteStarted;
  Future<void>? releaseDelete;
  int renameCalls = 0;

  @override
  String get id => "codex";

  @override
  String get launchDirectory => "/repo";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async => const [];

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {}

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    renameCalls++;
    return PluginSession(
      id: sessionId,
      projectID: "/repo",
      directory: "/repo",
      parentID: null,
      title: title,
      time: null,
      summary: null,
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deleteStarted?.complete();
    if (releaseDelete case final release?) await release;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
