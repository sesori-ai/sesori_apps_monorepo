import "dart:async";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionMutationDispatcher", () {
    late AppDatabase db;
    late SessionRepository repository;
    late SessionMutationDispatcher dispatcher;
    late _FakeDerivedPlugin plugin;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeDerivedPlugin();
      repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      dispatcher = SessionMutationDispatcher(sessionRepository: repository);
    });

    tearDown(() async {
      await dispatcher.dispose();
      await db.close();
    });

    Future<void> insertSession() async {
      await repository.insertStoredSession(
        sessionId: "s1",
        backendSessionId: "backend-s1",
        pluginId: "codex",
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
      await dispatcher.captureTitle(sessionId: "s1", title: "Early title");
      await insertSession();

      await dispatcher.applyPendingTitle(sessionId: "s1");

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "Early title");
    });

    test("rejects a rename when its root binding does not exist", () async {
      await expectLater(
        dispatcher.renameSession(sessionId: "s1", title: "User rename"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(plugin.renameCalls, isZero);
    });

    test("applies a pending null by removing the stored title copy", () async {
      await dispatcher.captureTitle(sessionId: "s1", title: null);
      await insertSession();
      await db.sessionDao.setTitle(sessionId: "s1", title: "stale", updatedAt: 2);

      await dispatcher.applyPendingTitle(sessionId: "s1");

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, isNull);
    });

    test("deletion discards a pending title", () async {
      plugin.sessions = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: null,
          time: null,
        ),
      ];
      await insertSession();
      final deletionEvent = expectLater(
        dispatcher.deletedSessions,
        emits(
          isA<Session>()
              .having((session) => session.id, "id", "s1")
              .having((session) => session.projectID, "projectID", "/repo"),
        ),
      );
      await dispatcher.captureTitle(sessionId: "s1", title: "stale");
      await dispatcher.deleteSession(sessionId: "s1");
      await deletionEvent;
      await insertSession();

      await dispatcher.applyPendingTitle(sessionId: "s1");

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, isNull);
    });

    test("a rename waits for deletion and cannot reach the plugin afterward", () async {
      final deleteStarted = Completer<void>();
      final releaseDelete = Completer<void>();
      plugin
        ..deleteStarted = deleteStarted
        ..releaseDelete = releaseDelete.future;
      await insertSession();

      final deletion = dispatcher.deleteSession(sessionId: "s1");
      await deleteStarted.future;
      final rename = dispatcher.renameSession(sessionId: "s1", title: "Resurrected");
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

    test("dispose waits for an in-flight deletion to emit", () async {
      final deleteStarted = Completer<void>();
      final releaseDelete = Completer<void>();
      plugin
        ..deleteStarted = deleteStarted
        ..releaseDelete = releaseDelete.future;
      await insertSession();
      final events = expectLater(
        dispatcher.deletedSessions,
        emitsInOrder([
          isA<Session>().having((session) => session.id, "id", "s1"),
          emitsDone,
        ]),
      );

      final deletion = dispatcher.deleteSession(sessionId: "s1");
      await deleteStarted.future;
      final disposal = dispatcher.dispose();
      releaseDelete.complete();

      await deletion;
      await disposal;
      await events;
      await expectLater(
        dispatcher.deleteSession(sessionId: "after-dispose"),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeDerivedPlugin implements BridgeDerivedProjectsPluginApi {
  Completer<void>? deleteStarted;
  Future<void>? releaseDelete;
  int renameCalls = 0;
  List<PluginSession> sessions = const [];

  @override
  String get id => "codex";

  @override
  String get launchDirectory => "/repo";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async => sessions;

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
