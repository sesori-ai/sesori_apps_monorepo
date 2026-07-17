import "dart:async";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/models/project_not_found_exception.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionRepository catalog reads", () {
    late AppDatabase database;

    setUp(() async {
      database = createTestDatabase();
      await database.projectsDao.recordOpenedProject(
        projectId: "project-X",
        path: "/projects/X",
        createdAt: 1,
        updatedAt: 1,
      );
    });

    tearDown(() => database.close());

    test("root pagination and unbounded offset use deterministic SQL order", () async {
      final repository = _repository(database: database, plugin: _ThrowingPlugin());
      addTearDown(repository.dispose);
      await _insertRoot(database: database, sessionId: "root-a", updatedAt: 10);
      await _insertRoot(database: database, sessionId: "root-b", updatedAt: 20);
      await _insertRoot(database: database, sessionId: "root-c", updatedAt: 20);

      final firstPage = await repository.getSessionsForProject(
        projectId: "project-X",
        start: 0,
        limit: 2,
      );
      final unboundedTail = await repository.getSessionsForProject(
        projectId: "project-X",
        start: 1,
        limit: null,
      );

      expect(firstPage.map((session) => session.id), ["root-c", "root-b"]);
      expect(unboundedTail.map((session) => session.id), ["root-b", "root-a"]);
    });

    test("list and detail map durable metadata without an operational owning plugin", () async {
      final plugin = _ThrowingPlugin();
      final repository = _repository(database: database, plugin: plugin);
      addTearDown(repository.dispose);
      await _insertRoot(
        database: database,
        sessionId: "stable-id",
        backendSessionId: "backend-id",
        pluginId: "offline-plugin",
        updatedAt: 20,
        catalogTitle: "Catalog title",
      );
      await database.sessionDao.setTitle(
        sessionId: "stable-id",
        title: "User title",
        updatedAt: 21,
        projectionUpdatedAt: 21,
      );

      final listed = await repository.getSessionsForProject(
        projectId: "project-X",
        start: null,
        limit: null,
      );
      final detail = await repository.getSessionForProject(
        projectId: "project-X",
        sessionId: "stable-id",
      );

      expect(listed.single.id, "stable-id");
      expect(listed.single.pluginId, "offline-plugin");
      expect(listed.single.title, "User title");
      expect(detail, listed.single);
      expect(plugin.calls, 0);
    });

    test("children retain durable history while every plugin read would throw", () async {
      final plugin = _ThrowingPlugin();
      final repository = _repository(database: database, plugin: plugin);
      addTearDown(repository.dispose);
      await _insertRoot(database: database, sessionId: "root", updatedAt: 1);
      await database.sessionDao.insertObservedChild(
        sessionId: "child",
        backendSessionId: "backend-child",
        projectId: "project-X",
        parentSessionId: "root",
        directory: "/projects/X/child",
        catalogTitle: "Child history",
        archivedAt: null,
        createdAt: 2,
        updatedAt: 3,
        projectionUpdatedAt: 3,
        pluginId: "offline-plugin",
      );

      final children = await repository.getChildSessions(sessionId: "root");

      expect(children.single.id, "child");
      expect(children.single.parentID, "root");
      expect(children.single.title, "Child history");
      expect(plugin.calls, 0);
    });

    test("catalog reads complete while plugin methods never complete", () async {
      final plugin = _NeverCompletingPlugin();
      final repository = _repository(database: database, plugin: plugin);
      addTearDown(repository.dispose);
      await _insertRoot(database: database, sessionId: "root", updatedAt: 1);

      final roots = await repository
          .getSessionsForProject(projectId: "project-X", start: null, limit: null)
          .timeout(const Duration(seconds: 1));
      final detail = await repository
          .getSessionForProject(projectId: "project-X", sessionId: "root")
          .timeout(const Duration(seconds: 1));
      final children = await repository.getChildSessions(sessionId: "root").timeout(const Duration(seconds: 1));

      expect(roots.single.id, "root");
      expect(detail?.id, "root");
      expect(children, isEmpty);
      expect(plugin.calls, 0);
    });

    test("unknown project and session ids preserve typed not-found behavior", () async {
      final repository = _repository(database: database, plugin: _ThrowingPlugin());
      addTearDown(repository.dispose);

      await expectLater(
        repository.getSessionsForProject(projectId: "missing", start: null, limit: null),
        throwsA(isA<ProjectNotFoundException>()),
      );
      expect(
        await repository.getSessionForProject(projectId: "project-X", sessionId: "missing"),
        isNull,
      );
      await expectLater(
        repository.getChildSessions(sessionId: "missing"),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 404)),
      );
    });

    test("local title and archive writes reject stale catalog projections", () async {
      final repository = _repository(database: database, plugin: _ThrowingPlugin());
      addTearDown(repository.dispose);
      await _insertRoot(
        database: database,
        sessionId: "stable-id",
        updatedAt: 200,
        catalogTitle: "New title",
      );

      await repository.setSessionTitleIfStored(sessionId: "stable-id", title: "Local title");
      final titledAt = (await database.sessionDao.getSession(sessionId: "stable-id"))!.projectionUpdatedAt;
      await repository.archiveStoredSession(sessionId: "stable-id", archivedAt: 300);
      final archivedAt = (await database.sessionDao.getSession(sessionId: "stable-id"))!.projectionUpdatedAt;
      expect(archivedAt, greaterThan(titledAt));

      await database.sessionDao.updateObservedSessionProjection(
        sessionId: "stable-id",
        directory: "/stale",
        catalogTitle: "Stale title",
        updateCatalogTitle: true,
        updatedAt: 100,
        projectionUpdatedAt: 100,
      );
      final row = await database.sessionDao.getSession(sessionId: "stable-id");
      expect(row?.directory, "/projects/X");
      expect(row?.catalogTitle, "New title");
      expect(row?.title, "Local title");
      expect(row?.archivedAt, 300);
    });
  });
}

SessionRepository _repository({required AppDatabase database, required BridgePluginApi plugin}) {
  return SessionRepository(
    plugin: plugin,
    projectsDao: database.projectsDao,
    sessionDao: database.sessionDao,
    pullRequestDao: database.pullRequestDao,
    unseenCalculator: const SessionUnseenCalculator(),
  );
}

Future<void> _insertRoot({
  required AppDatabase database,
  required String sessionId,
  String? backendSessionId,
  String pluginId = "offline-plugin",
  required int updatedAt,
  String? catalogTitle,
}) async {
  await database.sessionDao.insertSession(
    sessionId: sessionId,
    backendSessionId: backendSessionId ?? "backend-$sessionId",
    projectId: "project-X",
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
    pluginId: pluginId,
  );
  await database.sessionDao.updateObservedSessionProjection(
    sessionId: sessionId,
    directory: "/projects/X",
    catalogTitle: catalogTitle,
    updateCatalogTitle: true,
    updatedAt: updatedAt,
    projectionUpdatedAt: updatedAt,
  );
}

class _ThrowingPlugin implements NativeProjectsPluginApi {
  int calls = 0;

  @override
  String get id => "running-plugin";

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError("plugin member ${invocation.memberName} must not be called by catalog reads");
  }
}

class _NeverCompletingPlugin extends _ThrowingPlugin {
  @override
  Future<List<PluginProject>> getProjects() {
    calls++;
    return Completer<List<PluginProject>>().future;
  }

  @override
  Future<PluginProject> getProject(String projectId) {
    calls++;
    return Completer<PluginProject>().future;
  }

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) {
    calls++;
    return Completer<List<PluginSession>>().future;
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) {
    calls++;
    return Completer<List<PluginSession>>().future;
  }
}
