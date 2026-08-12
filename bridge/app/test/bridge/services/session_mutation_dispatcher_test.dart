import "dart:async";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_cleanup_result.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionMutationDispatcher", () {
    late AppDatabase db;
    late SessionRepository repository;
    late SessionOperationDispatcher operationDispatcher;
    late SessionMutationDispatcher dispatcher;
    late _FakeDerivedPlugin plugin;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeDerivedPlugin();
      repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      operationDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      dispatcher = SessionMutationDispatcher(
        sessionRepository: repository,
        sessionOperationDispatcher: operationDispatcher,
      );
    });

    tearDown(() async {
      await operationDispatcher.dispose();
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

    test("rejects a rename when its root binding does not exist", () async {
      await expectLater(
        dispatcher.renameSession(sessionId: "s1", title: "User rename"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(plugin.renameCalls, isZero);
    });

    test("holds the family operation through backend title propagation", () async {
      final renameStarted = Completer<void>();
      final releaseRename = Completer<void>();
      plugin
        ..renameStarted = renameStarted
        ..releaseRename = releaseRename.future;
      await insertSession();

      final rename = dispatcher.renameSession(sessionId: "s1", title: "Stored title");
      await renameStarted.future;
      var completed = false;
      unawaited(rename.then<void>((_) => completed = true));
      try {
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "Stored title");
      } finally {
        releaseRename.complete();
      }
      expect((await rename).title, "Stored title");
      expect(operationDispatcher.activeLaneCount, isZero);
    });

    test("keeps the stored title when plugin propagation fails", () async {
      plugin.renameError = StateError("rename failed");
      await insertSession();

      final renamed = await dispatcher.renameSession(sessionId: "s1", title: "Stored title");

      expect(renamed.title, "Stored title");
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "Stored title");
      expect(plugin.renameCalls, 1);
    });

    test("owns repository deletion and deleted session events", () async {
      await insertSession();
      final events = expectLater(
        dispatcher.deletedSessions,
        emitsInOrder([
          isA<Session>().having((session) => session.id, "id", "s1"),
          emitsDone,
        ]),
      );

      await dispatcher.deleteSession(
        sessionId: "s1",
        cleanup: () async => CleanupSuccess(),
        onDeleted: (_) async {},
      );
      await dispatcher.dispose();
      await events;
      expect(
        () => dispatcher.deleteSession(
          sessionId: "after-dispose",
          cleanup: () async => CleanupSuccess(),
          onDeleted: (_) async {},
        ),
        throwsStateError,
      );
    });
  });
}

class _FakeDerivedPlugin() implements BridgeDerivedProjectsPluginApi {
  Completer<void>? renameStarted;
  Future<void>? releaseRename;
  Object? renameError;
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
    if (renameStarted case final started? when !started.isCompleted) started.complete();
    if (releaseRename case final release?) await release;
    if (renameError case final error?) throw error;
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
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
