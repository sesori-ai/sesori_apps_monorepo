import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_cleanup_result.dart";
import "package:sesori_bridge/src/bridge/services/session_deletion_service.dart";
import "package:sesori_bridge/src/bridge/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("session family mutations", () {
    late _Fixture fixture;

    setUp(() {
      fixture = _Fixture();
    });

    tearDown(() => fixture.dispose());

    test("earlier child rename finishes before root deletion", () async {
      final renameStarted = Completer<void>();
      final releaseRename = Completer<void>();
      fixture.repository
        ..renameStarted["child"] = renameStarted
        ..renameGates["child"] = releaseRename.future;

      final rename = fixture.mutations.renameSession(sessionId: "child", title: "renamed");
      await renameStarted.future;
      final deletion = fixture.deleteRoot();
      await _flushEvents();

      expect(fixture.repository.deleteStarted.isCompleted, isFalse);
      releaseRename.complete();
      await Future.wait([rename, deletion]);
      expect(fixture.repository.contains(sessionId: "child"), isFalse);
    });

    test("earlier root deletion prevents a later child rename", () async {
      final releaseDelete = Completer<void>();
      fixture.repository.deleteGate = releaseDelete.future;

      final deletion = fixture.deleteRoot();
      await fixture.repository.deleteStarted.future;
      final rename = fixture.mutations.renameSession(sessionId: "child", title: "too late");
      await _flushEvents();

      expect(fixture.repository.renameCalls, isZero);
      releaseDelete.complete();
      await deletion;
      await expectLater(rename, throwsA(_isNotFound));
      expect(fixture.repository.renameCalls, isZero);
    });

    test("earlier child action finishes before root deletion", () async {
      final actionStarted = Completer<void>();
      final releaseAction = Completer<void>();
      fixture.repository
        ..actionStarted = actionStarted
        ..actionGate = releaseAction.future;

      final action = fixture.dispatchAction(sessionId: "child");
      await actionStarted.future;
      final deletion = fixture.deleteRoot();
      await _flushEvents();

      expect(fixture.repository.deleteStarted.isCompleted, isFalse);
      releaseAction.complete();
      await Future.wait([action, deletion]);
    });

    test("earlier root deletion prevents a later child action", () async {
      final releaseDelete = Completer<void>();
      fixture.repository.deleteGate = releaseDelete.future;

      final deletion = fixture.deleteRoot();
      await fixture.repository.deleteStarted.future;
      final action = fixture.dispatchAction(sessionId: "child");
      releaseDelete.complete();

      await deletion;
      await expectLater(action, throwsA(_isNotFound));
      expect(fixture.repository.actionCalls, isZero);
    });

    for (final archived in [true, false]) {
      final operationName = archived ? "archive" : "unarchive";

      test("earlier $operationName finishes before deletion", () async {
        fixture.repository.setArchived(sessionId: "root", archived: !archived);
        final lifecycleStarted = Completer<void>();
        final releaseLifecycle = Completer<void>();
        if (archived) {
          fixture.repository
            ..archiveStarted = lifecycleStarted
            ..archiveGate = releaseLifecycle.future;
        } else {
          fixture.worktree
            ..restoreStarted = lifecycleStarted
            ..restoreGate = releaseLifecycle.future;
        }

        final lifecycle = fixture.updateArchiveStatus(archived: archived);
        await lifecycleStarted.future;
        final deletion = fixture.deleteRoot();
        await _flushEvents();

        expect(fixture.repository.deleteStarted.isCompleted, isFalse);
        releaseLifecycle.complete();
        await Future.wait([lifecycle, deletion]);
      });

      test("earlier deletion prevents later $operationName", () async {
        fixture.repository.setArchived(sessionId: "root", archived: !archived);
        final releaseDelete = Completer<void>();
        fixture.repository.deleteGate = releaseDelete.future;

        final deletion = fixture.deleteRoot();
        await fixture.repository.deleteStarted.future;
        final lifecycle = fixture.updateArchiveStatus(archived: archived);
        releaseDelete.complete();

        await deletion;
        await expectLater(lifecycle, throwsA(_isNotFound));
        expect(fixture.worktree.restoreCalls, isZero);
      });
    }

    test("cleanup rejection releases the family without deleting", () async {
      fixture.worktree.safetyResult = WorktreeUnsafe(issues: [UnstagedChanges()]);

      final result = await fixture.deletions.deleteSession(
        sessionId: "root",
        deleteWorktree: true,
        deleteBranch: false,
        force: false,
      );

      expect(result, isA<CleanupRejected>());
      expect(fixture.repository.deleteCalls, isZero);
      expect(fixture.repository.contains(sessionId: "root"), isTrue);
      expect(fixture.operations.activeLaneCount, isZero);
    });

    test("unrelated roots and plugins execute while one family is blocked", () async {
      final childStarted = Completer<void>();
      final releaseChild = Completer<void>();
      final otherStarted = Completer<void>();
      final pluginTwoStarted = Completer<void>();
      fixture.repository
        ..renameStarted["child"] = childStarted
        ..renameGates["child"] = releaseChild.future
        ..renameStarted["other"] = otherStarted
        ..renameStarted["plugin-two"] = pluginTwoStarted;

      final child = fixture.mutations.renameSession(sessionId: "child", title: "child");
      await childStarted.future;
      final other = fixture.mutations.renameSession(sessionId: "other", title: "other");
      final pluginTwo = fixture.mutations.renameSession(sessionId: "plugin-two", title: "plugin two");

      await Future.wait([otherStarted.future, pluginTwoStarted.future, other, pluginTwo]);
      releaseChild.complete();
      await child;
      expect(fixture.operations.activeLaneCount, isZero);
    });

    test("failure releases the lane for later family work", () async {
      fixture.repository.titleWriteError = StateError("title write failed");

      await expectLater(
        fixture.mutations.renameSession(sessionId: "child", title: "fails"),
        throwsStateError,
      );
      await fixture.dispatchAction(sessionId: "root");

      expect(fixture.repository.actionCalls, 1);
      expect(fixture.operations.activeLaneCount, isZero);
    });

    test("drain waits for accepted work, rejects new work, and disposes once", () async {
      final actionStarted = Completer<void>();
      final releaseAction = Completer<void>();
      fixture.repository
        ..actionStarted = actionStarted
        ..actionGate = releaseAction.future;
      final action = fixture.dispatchAction(sessionId: "child");
      await actionStarted.future;

      final drain = fixture.operations.drain();
      var drained = false;
      unawaited(drain.then<void>((_) => drained = true));
      await _flushEvents();
      expect(drained, isFalse);
      expect(
        () => fixture.mutations.renameSession(sessionId: "root", title: "closed"),
        throwsStateError,
      );

      releaseAction.complete();
      await Future.wait([action, drain]);
      expect(identical(drain, fixture.operations.dispose()), isTrue);
      expect(fixture.operations.activeLaneCount, isZero);
    });
  });
}

final _isNotFound = isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue);

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

class _Fixture {
  late final _FamilyRepository repository;
  late final SessionOperationDispatcher operations;
  late final SessionMutationDispatcher mutations;
  late final _FamilyWorktreeService worktree;
  late final SessionLifecycleService lifecycle;
  late final SessionDeletionService deletions;

  _Fixture() {
    repository = _FamilyRepository();
    operations = SessionOperationDispatcher(sessionRepository: repository);
    mutations = SessionMutationDispatcher(
      sessionRepository: repository,
      sessionOperationDispatcher: operations,
    );
    worktree = _FamilyWorktreeService();
    lifecycle = SessionLifecycleService(
      worktreeService: worktree,
      sessionRepository: repository,
      filesystemRepository: _MissingFilesystemRepository(),
      sessionOperationDispatcher: operations,
    );
    deletions = SessionDeletionService(
      sessionLifecycleService: lifecycle,
      sessionMutationDispatcher: mutations,
    );
  }

  Future<void> deleteRoot() async {
    final result = await deletions.deleteSession(
      sessionId: "root",
      deleteWorktree: false,
      deleteBranch: false,
      force: false,
    );
    if (result is CleanupRejected) throw StateError("unexpected cleanup rejection");
  }

  Future<ArchiveStatusUpdate> updateArchiveStatus({required bool archived}) {
    return lifecycle.updateArchiveStatus(
      sessionId: "root",
      archived: archived,
      deleteWorktree: false,
      deleteBranch: false,
      force: false,
    );
  }

  Future<void> dispatchAction({required String sessionId}) {
    return operations.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.sendPrompt,
      interaction: null,
      body: () => repository.executeAction(sessionId: sessionId),
    );
  }

  Future<void> dispose() async {
    await operations.dispose();
    await mutations.dispose();
  }
}

class _FamilyRepository implements SessionRepository {
  final Map<String, _SessionRecord> _sessions = {
    "root": _SessionRecord(id: "root", rootId: "root", parentId: null, pluginId: "one"),
    "child": _SessionRecord(id: "child", rootId: "root", parentId: "root", pluginId: "one"),
    "other": _SessionRecord(id: "other", rootId: "other", parentId: null, pluginId: "one"),
    "plugin-two": _SessionRecord(id: "plugin-two", rootId: "plugin-two", parentId: null, pluginId: "two"),
  };
  final Map<String, Completer<void>> renameStarted = {};
  final Map<String, Future<void>> renameGates = {};
  final Completer<void> deleteStarted = Completer<void>();
  Completer<void>? archiveStarted;
  Completer<void>? actionStarted;
  Future<void>? archiveGate;
  Future<void>? deleteGate;
  Future<void>? actionGate;
  Object? titleWriteError;
  int renameCalls = 0;
  int deleteCalls = 0;
  int actionCalls = 0;

  bool contains({required String sessionId}) => _sessions.containsKey(sessionId);

  void setArchived({required String sessionId, required bool archived}) {
    final record = _sessions[sessionId];
    if (record == null) throw StateError("missing test session $sessionId");
    record.archivedAt = archived ? 1 : null;
  }

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final record = _sessions[sessionId];
    if (record == null) throw _notFound(sessionId: sessionId, operation: operation);
    return (rootSessionId: record.rootId, pluginId: record.pluginId);
  }

  @override
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) async {
    final error = titleWriteError;
    titleWriteError = null;
    if (error != null) throw error;
    final record = _sessions[sessionId];
    if (record == null) return false;
    record.title = title;
    return true;
  }

  @override
  Future<Session?> getCatalogSession({required String sessionId}) async => _sessions[sessionId]?.session;

  @override
  Future<Session> renameSession({required String sessionId, required String title}) async {
    renameCalls++;
    renameStarted[sessionId]?.complete();
    final gate = renameGates[sessionId];
    if (gate != null) await gate;
    final record = _sessions[sessionId];
    if (record == null) throw _notFound(sessionId: sessionId, operation: SessionOperation.renameSession);
    return record.session;
  }

  @override
  Future<Session> deleteSession({required String sessionId}) async {
    deleteCalls++;
    if (!deleteStarted.isCompleted) deleteStarted.complete();
    final snapshot = _sessions[sessionId];
    if (snapshot == null) throw _notFound(sessionId: sessionId, operation: SessionOperation.deleteSession);
    final gate = deleteGate;
    if (gate != null) await gate;
    if (!_sessions.containsKey(sessionId)) {
      throw _notFound(sessionId: sessionId, operation: SessionOperation.deleteSession);
    }
    _sessions.removeWhere((_, record) => record.rootId == sessionId || record.id == sessionId);
    return snapshot.session;
  }

  @override
  Future<StoredSession> requireRoutableStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final record = _sessions[sessionId];
    if (record == null) throw _notFound(sessionId: sessionId, operation: operation);
    return record.stored;
  }

  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async => false;

  @override
  Future<void> archiveStoredSession({required String sessionId, required int archivedAt}) async {
    final started = archiveStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = archiveGate;
    if (gate != null) await gate;
    final record = _sessions[sessionId];
    if (record == null) throw _notFound(sessionId: sessionId, operation: SessionOperation.archiveSession);
    record.archivedAt = archivedAt;
  }

  @override
  Future<void> unarchiveStoredSession({required String sessionId}) async {
    final record = _sessions[sessionId];
    if (record == null) throw _notFound(sessionId: sessionId, operation: SessionOperation.updateSessionArchiveStatus);
    record.archivedAt = null;
  }

  @override
  Future<void> notifySessionArchived({required String sessionId}) async {}

  Future<void> executeAction({required String sessionId}) async {
    final started = actionStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = actionGate;
    if (gate != null) await gate;
    if (!_sessions.containsKey(sessionId)) {
      throw _notFound(sessionId: sessionId, operation: SessionOperation.sendPrompt);
    }
    actionCalls++;
  }

  PluginOperationException _notFound({required String sessionId, required SessionOperation operation}) {
    return PluginOperationException.notFound(operation.name, message: "session $sessionId was not found");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionRecord {
  final String id;
  final String rootId;
  final String? parentId;
  final String pluginId;
  String? title;
  int? archivedAt;

  _SessionRecord({
    required this.id,
    required this.rootId,
    required this.parentId,
    required this.pluginId,
  }) : title = id;

  StoredSession get stored => StoredSession(
    id: id,
    backendSessionId: "backend-$id",
    pluginId: pluginId,
    projectId: "project-$rootId",
    parentSessionId: parentId,
    directory: "/repo/$id",
    worktreePath: "/repo/.worktrees/$id",
    branchName: "branch-$id",
    isDedicated: true,
    archivedAt: archivedAt,
    baseBranch: "main",
    baseCommit: "abc123",
  );

  Session get session => Session(
    id: id,
    pluginId: pluginId,
    projectID: "project-$rootId",
    directory: "/repo/$id",
    parentID: parentId,
    title: title,
    time: SessionTime(created: 1, updated: 1, archived: archivedAt),
    pullRequest: null,
    promptDefaults: null,
    branchName: "branch-$id",
  );
}

class _FamilyWorktreeService implements WorktreeService {
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  Completer<void>? restoreStarted;
  Future<void>? restoreGate;
  int restoreCalls = 0;

  @override
  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
    required String expectedBranch,
  }) async => safetyResult;

  @override
  Future<bool> removeWorktree({
    required String pluginId,
    required String projectId,
    required String worktreePath,
    required bool force,
  }) async => true;

  @override
  Future<bool> deleteBranch({required String projectId, required String branchName, required bool force}) async => true;

  @override
  Future<bool> branchExists({required String projectId, required String branchName}) async => false;

  @override
  Future<bool> restoreWorktree({
    required String projectId,
    required String worktreePath,
    required String branchName,
    required String baseBranch,
    required String? baseCommit,
  }) async {
    restoreCalls++;
    final started = restoreStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = restoreGate;
    if (gate != null) await gate;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MissingFilesystemRepository implements FilesystemRepository {
  @override
  bool directoryExists({required String path}) => false;

  @override
  FilesystemEntityKind classifyPath({required String path}) => FilesystemEntityKind.notFound;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
