import "dart:async";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/services/session_cleanup_result.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_derived_bridge_plugin.dart";
import "../../helpers/test_database.dart";

void main() {
  group("SessionMutationDispatcher", () {
    late AppDatabase db;
    late SessionRepository repository;
    late SessionOperationDispatcher operationDispatcher;
    late SessionMutationDispatcher dispatcher;
    late _FakeDerivedPlugin plugin;
    late _FakeWorktreeService worktreeService;

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
      worktreeService = _FakeWorktreeService();
      dispatcher = SessionMutationDispatcher(
        sessionRepository: repository,
        sessionOperationDispatcher: operationDispatcher,
        worktreeService: worktreeService,
      );
    });

    tearDown(() async {
      await operationDispatcher.dispose();
      await dispatcher.dispose();
      await db.close();
    });

    Future<void> insertSession({
      bool isDedicated = false,
      String? worktreePath,
      String? branchName,
    }) async {
      await insertTestSession(
        db: db,
        sessionId: "s1",
        backendSessionId: "backend-s1",
        pluginId: "codex",
        projectId: "/repo",
        isDedicated: isDedicated,
        createdAt: 1,
        worktreePath: worktreePath,
        branchName: branchName,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
    }

    Future<void> insertChild() {
      return db.sessionDao.insertObservedChild(
        pluginId: plugin.id,
        sessionId: "child",
        backendSessionId: "backend-child",
        projectId: "/repo",
        parentSessionId: "s1",
        directory: "/repo",
        catalogTitle: null,
        archivedAt: null,
        createdAt: 1,
        updatedAt: 1,
        projectionUpdatedAt: 1,
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

      final mutations = <LocalSessionMutation>[];
      final subscription = dispatcher.mutations.listen(mutations.add);
      final rename = dispatcher.renameSession(sessionId: "s1", title: "Stored title");
      await renameStarted.future;
      var completed = false;
      unawaited(rename.then<void>((_) => completed = true));
      try {
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "Stored title");
        expect(
          mutations.single,
          isA<SessionTitleUpdated>().having((mutation) => mutation.session.title, "title", "Stored title"),
        );
      } finally {
        releaseRename.complete();
      }
      expect((await rename).title, "Stored title");
      expect(operationDispatcher.activeLaneCount, isZero);
      await subscription.cancel();
    });

    test("generated title emits before propagation and catalogTitle does not block", () async {
      final renameStarted = Completer<void>();
      final releaseRename = Completer<void>();
      plugin
        ..renameStarted = renameStarted
        ..releaseRename = releaseRename.future;
      await insertSession();
      await db.sessionDao.updateObservedSessionProjection(
        sessionId: "s1",
        directory: "/repo",
        catalogTitle: "Catalog title",
        updateCatalogTitle: true,
        updatedAt: 2,
        projectionUpdatedAt: 2,
      );
      final mutations = <LocalSessionMutation>[];
      final subscription = dispatcher.mutations.listen(mutations.add);

      final update = dispatcher.applyGeneratedTitle(sessionId: "s1", title: "Generated title");
      await renameStarted.future;

      expect(
        mutations.single,
        isA<SessionTitleUpdated>().having((mutation) => mutation.session.title, "title", "Generated title"),
      );
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "Generated title");
      releaseRename.complete();
      expect((await update)?.title, "Generated title");
      await subscription.cancel();
    });

    test("generated title does not propagate after user rename wins", () async {
      await insertSession();
      await dispatcher.renameSession(sessionId: "s1", title: "User title");
      final mutations = <LocalSessionMutation>[];
      final subscription = dispatcher.mutations.listen(mutations.add);

      final updated = await dispatcher.applyGeneratedTitle(sessionId: "s1", title: "Generated title");

      expect(updated, isNull);
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "User title");
      expect(plugin.renameCalls, 1);
      expect(mutations, isEmpty);
      await subscription.cancel();
    });

    test("generated title does not propagate when deletion wins", () async {
      await insertSession();
      await dispatcher.deleteSession(
        sessionId: "s1",
        cleanup: () async => CleanupSuccess(),
        onDeleted: (_) async {},
      );
      final mutations = <LocalSessionMutation>[];
      final subscription = dispatcher.mutations.listen(mutations.add);

      await expectLater(
        dispatcher.applyGeneratedTitle(sessionId: "s1", title: "Generated title"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );

      expect(plugin.renameCalls, isZero);
      expect(mutations, isEmpty);
      await subscription.cancel();
    });

    test("suppresses events from deletion start and restores them when cleanup fails", () async {
      await insertSession();
      await insertChild();
      final cleanupStarted = Completer<void>();
      final cleanupGate = Completer<void>();
      final deletion = dispatcher.deleteSession(
        sessionId: "s1",
        cleanup: () async {
          cleanupStarted.complete();
          await cleanupGate.future;
          throw StateError("cleanup failed");
        },
        onDeleted: (_) async {},
      );
      await cleanupStarted.future;

      expect(dispatcher.shouldSuppressEventsForSession(sessionId: "s1"), isTrue);
      expect(dispatcher.shouldSuppressEventsForSession(sessionId: "child"), isTrue);

      final failure = expectLater(deletion, throwsStateError);
      cleanupGate.complete();
      await failure;

      expect(dispatcher.shouldSuppressEventsForSession(sessionId: "s1"), isFalse);
      expect(dispatcher.shouldSuppressEventsForSession(sessionId: "child"), isFalse);
      expect(await db.sessionDao.getSession(sessionId: "s1"), isNotNull);
    });

    test("rolls back root suppression when its subtree lookup fails", () async {
      final gatedRepository = _GatedSubtreeSessionRepository();
      final gatedOperationDispatcher = SessionOperationDispatcher(sessionRepository: gatedRepository);
      final gatedDispatcher = SessionMutationDispatcher(
        sessionRepository: gatedRepository,
        sessionOperationDispatcher: gatedOperationDispatcher,
        worktreeService: worktreeService,
      );
      final deletion = gatedDispatcher.deleteSession(
        sessionId: "s1",
        cleanup: () => throw StateError("cleanup failed"),
        onDeleted: (_) async {},
      );
      await gatedRepository.lookupStarted.future;

      expect(gatedDispatcher.shouldSuppressEventsForSession(sessionId: "s1"), isTrue);

      final failure = expectLater(deletion, throwsStateError);
      gatedRepository.releaseLookup.complete();
      await failure;
      expect(gatedDispatcher.shouldSuppressEventsForSession(sessionId: "s1"), isFalse);
      await gatedOperationDispatcher.dispose();
      await gatedDispatcher.dispose();
    });

    test("keeps the generated title when plugin propagation fails", () async {
      plugin.renameError = StateError("rename failed");
      await insertSession();

      final renamed = await dispatcher.applyGeneratedTitle(sessionId: "s1", title: "Generated title");

      expect(renamed?.title, "Generated title");
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "Generated title");
      expect(plugin.renameCalls, 1);
    });

    test("persists a generated branch and emits the updated session", () async {
      await insertSession(
        isDedicated: true,
        worktreePath: "/repo/.worktrees/blue-otter",
        branchName: "blue-otter",
      );
      worktreeService.renameResult = GeneratedBranchRenamed(branchName: "fix-login-flow");
      final mutations = <LocalSessionMutation>[];
      final subscription = dispatcher.mutations.listen(mutations.add);

      final updated = await dispatcher.applyGeneratedBranchName(
        sessionId: "s1",
        branchName: "fix-login-flow",
      );

      final stored = await db.sessionDao.getSession(sessionId: "s1");
      expect(updated?.branchName, "fix-login-flow");
      expect(stored?.branchName, "fix-login-flow");
      expect(stored?.currentBranchName, "fix-login-flow");
      expect(worktreeService.renameCalls, 1);
      expect(
        mutations.single,
        isA<SessionBranchUpdated>().having(
          (mutation) => mutation.session.branchName,
          "branchName",
          "fix-login-flow",
        ),
      );
      await subscription.cancel();
    });

    test("rolls back Git when conditional branch persistence loses", () async {
      await insertSession(
        isDedicated: true,
        worktreePath: "/repo/.worktrees/blue-otter",
        branchName: "blue-otter",
      );
      worktreeService
        ..renameResult = GeneratedBranchRenamed(branchName: "fix-login-flow")
        ..onRename = () async {
          await db.sessionDao.replaceGeneratedBranch(
            sessionId: "s1",
            expectedBranchName: "blue-otter",
            branchName: "user-branch",
          );
        };
      final mutations = <LocalSessionMutation>[];
      final subscription = dispatcher.mutations.listen(mutations.add);

      final updated = await dispatcher.applyGeneratedBranchName(
        sessionId: "s1",
        branchName: "fix-login-flow",
      );

      expect(updated, isNull);
      expect(worktreeService.rollbackCalls, 1);
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.branchName, "user-branch");
      expect(mutations, isEmpty);
      await subscription.cancel();
    });

    test("contains rollback failure when conditional branch persistence loses", () async {
      await insertSession(
        isDedicated: true,
        worktreePath: "/repo/.worktrees/blue-otter",
        branchName: "blue-otter",
      );
      worktreeService
        ..renameResult = GeneratedBranchRenamed(branchName: "fix-login-flow")
        ..rollbackError = StateError("rollback failed")
        ..onRename = () async {
          await db.sessionDao.replaceGeneratedBranch(
            sessionId: "s1",
            expectedBranchName: "blue-otter",
            branchName: "user-branch",
          );
        };

      expect(
        await dispatcher.applyGeneratedBranchName(
          sessionId: "s1",
          branchName: "fix-login-flow",
        ),
        isNull,
      );
      expect(worktreeService.rollbackCalls, 1);
    });

    test("does not invoke Git for an in-place session", () async {
      await insertSession();

      expect(
        await dispatcher.applyGeneratedBranchName(
          sessionId: "s1",
          branchName: "fix-login-flow",
        ),
        isNull,
      );
      expect(worktreeService.renameCalls, isZero);
    });

    test("owns repository deletion and typed deleted mutations", () async {
      await insertSession();
      await insertChild();
      final events = expectLater(
        dispatcher.mutations,
        emitsInOrder([
          isA<SessionDeleted>().having((mutation) => mutation.session.id, "id", "s1"),
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
      expect(dispatcher.shouldSuppressEventsForSession(sessionId: "s1"), isTrue);
      expect(dispatcher.shouldSuppressEventsForSession(sessionId: "child"), isTrue);
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

class _FakeWorktreeService() implements WorktreeService {
  GeneratedBranchRenameResult renameResult = GeneratedBranchRenameSkipped(
    reason: GeneratedBranchRenameSkipReason.initialBranchChanged,
  );
  Object? renameError;
  Object? rollbackError;
  int renameCalls = 0;
  int rollbackCalls = 0;
  Future<void> Function()? onRename;

  @override
  Future<GeneratedBranchRenameResult> renameGeneratedBranch({
    required String worktreePath,
    required String initialBranchName,
    required String generatedBranchName,
  }) async {
    renameCalls++;
    if (onRename case final callback?) await callback();
    if (renameError case final error?) throw error;
    return renameResult;
  }

  @override
  Future<void> rollbackGeneratedBranchRename({
    required String worktreePath,
    required String generatedBranchName,
    required String initialBranchName,
  }) async {
    rollbackCalls++;
    if (rollbackError case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GatedSubtreeSessionRepository() implements SessionRepository {
  final Completer<void> lookupStarted = Completer<void>();
  final Completer<void> releaseLookup = Completer<void>();

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => (rootSessionId: sessionId, pluginId: "codex");

  @override
  Future<List<String>> getSessionSubtreeIds({required String sessionId}) async {
    lookupStarted.complete();
    await releaseLookup.future;
    throw StateError("subtree lookup failed");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDerivedPlugin() extends FakeDerivedBridgePlugin {
  this : super(id: "codex", launchDirectory: "/repo", allSessions: const []);

  Completer<void>? renameStarted;
  Future<void>? releaseRename;
  Object? renameError;
  Completer<void>? deleteStarted;
  Future<void>? releaseDelete;
  int renameCalls = 0;

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
}
