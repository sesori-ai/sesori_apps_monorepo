import "dart:async";

import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionRepository root publication", () {
    late AppDatabase db;
    late _FakeNativePlugin plugin;
    late SessionRepository repository;

    setUp(() async {
      db = createTestDatabase();
      plugin = _FakeNativePlugin();
      repository = _repository(db: db, plugin: plugin, sessionDao: db.sessionDao);
      await db.projectsDao.recordOpenedProject(
        projectId: "project-X",
        path: "/projects/X",
        createdAt: 1,
        updatedAt: 1,
      );
    });

    tearDown(() async {
      await repository.dispose();
      await db.close();
    });

    test("getSessionsForProject publishes every binding before returning", () async {
      plugin.sessions = List<PluginSession>.generate(
        5,
        (index) => _pluginSession(
          id: "backend-$index",
          directory: "/projects/X",
          title: "Session $index",
          createdAt: 1000 + index,
        ),
      );

      final commitFuture = repository.bindingCommits.first;
      final sessions = await repository.getSessionsForProject(
        projectId: "project-X",
        start: null,
        limit: null,
      );
      final commit = await commitFuture;
      final rows = await db.select(db.sessionTable).get();

      expect(commit.pluginId, plugin.id);
      expect(
        commit.backendSessionIds,
        unorderedEquals(["backend-0", "backend-1", "backend-2", "backend-3", "backend-4"]),
      );
      expect(sessions.map((session) => session.id), everyElement(startsWith("ses_")));
      expect(rows, hasLength(5));
      for (final row in rows) {
        expect(row.sessionId, isNot(row.backendSessionId));
        expect(row.pluginId, equals(plugin.id));
        expect(row.projectId, equals("project-X"));
        expect(row.directory, equals("/projects/X"));
      }
    });

    test("publication preserves a stable id and worktree state for an existing backend binding", () async {
      await repository.insertStoredSession(
        sessionId: "stable-id",
        backendSessionId: "backend-id",
        pluginId: plugin.id,
        projectId: "project-X",
        isDedicated: true,
        createdAt: 123,
        worktreePath: "/projects/X/.worktrees/stable-id",
        branchName: "feature/stable-id",
        baseBranch: "main",
        baseCommit: "abc123",
        agent: "agent-1",
        agentModel: const AgentModel(
          providerID: "provider-1",
          modelID: "model-1",
          variant: "high",
        ),
      );
      plugin.sessions = [
        _pluginSession(
          id: "backend-id",
          directory: "/projects/X/.worktrees/stable-id",
          title: "Backend title",
          createdAt: 999,
        ),
      ];

      final sessions = await repository.getSessionsForProject(
        projectId: "project-X",
        start: null,
        limit: null,
      );
      final row = await db.sessionDao.getSession(sessionId: "stable-id");

      expect(sessions.single.id, equals("stable-id"));
      expect(row?.backendSessionId, equals("backend-id"));
      expect(row?.worktreePath, equals("/projects/X/.worktrees/stable-id"));
      expect(row?.branchName, equals("feature/stable-id"));
      expect(row?.isDedicated, isTrue);
      expect(row?.lastAgent, equals("agent-1"));
      expect(row?.lastAgentModel?.modelID, equals("model-1"));
    });

    test("publication preserves stored timestamps when the plugin omits time", () async {
      await repository.insertStoredSession(
        sessionId: "stable-id",
        backendSessionId: "backend-id",
        pluginId: plugin.id,
        projectId: "project-X",
        isDedicated: false,
        createdAt: 123,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
      plugin.sessions = const [
        PluginSession(
          id: "backend-id",
          projectID: "project-X",
          directory: "/projects/X",
          parentID: null,
          title: "Untimed session",
          time: null,
        ),
      ];

      final sessions = await repository.getSessionsForProject(
        projectId: "project-X",
        start: null,
        limit: null,
      );
      final row = await db.sessionDao.getSession(sessionId: "stable-id");

      expect(sessions.single.time?.created, 123);
      expect(sessions.single.time?.updated, 123);
      expect(row?.createdAt, 123);
      expect(row?.updatedAt, 123);
    });

    test("bridge title override wins over later catalog publication", () async {
      plugin.sessions = [
        _pluginSession(
          id: "backend-id",
          directory: "/projects/X",
          title: "Initial catalog title",
          createdAt: 10,
        ),
      ];
      final first = await repository.getSessionsForProject(projectId: "project-X", start: null, limit: null);
      await repository.setSessionTitleIfStored(sessionId: first.single.id, title: "User title");
      plugin.sessions = [
        _pluginSession(
          id: "backend-id",
          directory: "/projects/X",
          title: "Later catalog title",
          createdAt: 20,
        ),
      ];

      final sessions = await repository.getSessionsForProject(
        projectId: "project-X",
        start: null,
        limit: null,
      );

      expect(sessions.single.title, equals("User title"));
      expect((await db.sessionDao.getSession(sessionId: first.single.id))?.catalogTitle, equals("Later catalog title"));
    });

    test("older projections cannot overwrite a newer catalog projection", () async {
      await db.sessionDao.upsertObservedRootSessions(
        pluginId: plugin.id,
        sessions: [
          _observedRoot(title: "New title", updatedAt: 200, projectionUpdatedAt: 200),
        ],
      );
      await db.sessionDao.upsertObservedRootSessions(
        pluginId: plugin.id,
        sessions: [
          _observedRoot(title: "Stale title", updatedAt: 100, projectionUpdatedAt: 100),
        ],
      );

      final row = await db.sessionDao.getSession(sessionId: "stable-id");
      expect(row?.catalogTitle, equals("New title"));
      expect(row?.updatedAt, equals(200));
      expect(row?.projectionUpdatedAt, equals(200));
    });

    test("publication transaction leaves no partial bindings when the batch fails", () async {
      plugin.sessions = [
        _pluginSession(id: "backend-1", directory: "/projects/X", title: null, createdAt: 1),
        _pluginSession(id: "backend-2", directory: "/projects/X", title: null, createdAt: 2),
      ];
      final failingRepository = _repository(
        db: db,
        plugin: plugin,
        sessionDao: _ThrowingSessionDao(db: db),
      );

      await expectLater(
        failingRepository.getSessionsForProject(projectId: "project-X", start: null, limit: null),
        throwsStateError,
      );
      expect(await db.select(db.sessionTable).get(), isEmpty);
    });

    test("stale enumeration cannot recreate a session deleted before publication", () async {
      await repository.insertStoredSession(
        sessionId: "stable-id",
        backendSessionId: "backend-id",
        pluginId: plugin.id,
        projectId: "project-X",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
      plugin.sessions = [
        _pluginSession(
          id: "backend-id",
          directory: "/projects/X",
          title: "Stale session",
          createdAt: 1,
        ),
      ];
      final fetchStarted = Completer<void>();
      final releaseFetch = Completer<void>();
      plugin.fetchStarted = fetchStarted;
      plugin.releaseFetch = releaseFetch.future;

      final sessionsFuture = repository.getSessionsForProject(
        projectId: "project-X",
        start: null,
        limit: null,
      );
      await fetchStarted.future;
      await repository.deleteSession(sessionId: "stable-id");
      releaseFetch.complete();

      expect(await sessionsFuture, isEmpty);
      expect(await db.sessionDao.getSession(sessionId: "stable-id"), isNull);
      expect(
        await db.sessionDao.getTombstonedSessionIds(pluginId: plugin.id),
        contains("backend-id"),
      );
    });

    test("a backend id matching another plugin's stable id receives an independent random id", () async {
      await db.sessionDao.insertSession(
        pluginId: "other-plugin",
        sessionId: "collision-id",
        backendSessionId: "other-backend-id",
        projectId: "project-X",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );
      plugin.sessions = [
        _pluginSession(
          id: "collision-id",
          directory: "/projects/X",
          title: "Colliding session",
          createdAt: 1,
        ),
        _pluginSession(
          id: "backend-live",
          directory: "/projects/X",
          title: "Live session",
          createdAt: 2,
        ),
      ];

      final sessions = await repository.getSessionsForProject(
        projectId: "project-X",
        start: null,
        limit: null,
      );
      final retained = await db.sessionDao.getSession(sessionId: "collision-id");

      expect(sessions, hasLength(2));
      expect(sessions.map((session) => session.id), everyElement(startsWith("ses_")));
      expect(retained?.pluginId, "other-plugin");
      expect(retained?.backendSessionId, "other-backend-id");
      expect(
        (await db.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "collision-id",
        ))?.sessionId,
        isNot("collision-id"),
      );
      expect(
        await db.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "backend-live",
        ),
        isNotNull,
      );
    });

    test("concurrent list publications reuse one random binding", () async {
      plugin.sessions = [
        _pluginSession(
          id: "backend-race",
          directory: "/projects/X",
          title: "Race",
          createdAt: 1,
        ),
      ];

      final results = await Future.wait([
        repository.getSessionsForProject(projectId: "project-X", start: null, limit: null),
        repository.getSessionsForProject(projectId: "project-X", start: null, limit: null),
      ]);
      final binding = await db.sessionDao.getSessionByBinding(
        pluginId: plugin.id,
        backendSessionId: "backend-race",
      );

      expect(results[0].single.id, results[1].single.id);
      expect(results[0].single.id, binding?.sessionId);
      expect(results[0].single.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(await db.select(db.sessionTable).get(), hasLength(1));
    });

    test("create and list publication races converge on one binding", () async {
      final racingPlugin = _RacingNativePlugin()
        ..sessions = [
          _pluginSession(
            id: "backend-create-race",
            directory: "/projects/X",
            title: "Race",
            createdAt: 1,
          ),
        ];
      final racingRepository = _repository(
        db: db,
        plugin: racingPlugin,
        sessionDao: db.sessionDao,
      );

      final createFuture = racingRepository.createSession(
        pluginId: racingPlugin.id,
        projectId: "project-X",
        directory: "/projects/X",
        parentSessionId: null,
        parts: const [],
        variant: null,
        agent: null,
        model: null,
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );
      final listFuture = racingRepository.getSessionsForProject(
        projectId: "project-X",
        start: null,
        limit: null,
      );
      final created = await createFuture;
      final listed = await listFuture;
      final binding = await db.sessionDao.getSessionByBinding(
        pluginId: racingPlugin.id,
        backendSessionId: "backend-create-race",
      );

      expect(created.id, listed.single.id);
      expect(created.id, binding?.sessionId);
      expect(created.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(await db.select(db.sessionTable).get(), hasLength(1));
    });
  });

  group("SessionRepository stored archive state", () {
    test("archive and unarchive update an existing binding", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final plugin = _FakeNativePlugin();
      final repository = _repository(db: db, plugin: plugin, sessionDao: db.sessionDao);
      await repository.insertStoredSession(
        sessionId: "stable-id",
        backendSessionId: "backend-id",
        pluginId: plugin.id,
        projectId: "project-X",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );

      await repository.archiveStoredSession(sessionId: "stable-id", archivedAt: 777);
      expect((await db.sessionDao.getSession(sessionId: "stable-id"))?.archivedAt, equals(777));

      await repository.unarchiveStoredSession(sessionId: "stable-id");
      expect((await db.sessionDao.getSession(sessionId: "stable-id"))?.archivedAt, isNull);
    });
  });
}

SessionRepository _repository({
  required AppDatabase db,
  required BridgePluginApi plugin,
  required SessionDao sessionDao,
}) {
  return SessionRepository(
    plugin: plugin,
    projectsDao: db.projectsDao,
    sessionDao: sessionDao,
    pullRequestDao: db.pullRequestDao,
    unseenCalculator: const SessionUnseenCalculator(),
  );
}

PluginSession _pluginSession({
  required String id,
  required String directory,
  required String? title,
  required int createdAt,
}) {
  return PluginSession(
    id: id,
    projectID: "project-X",
    directory: directory,
    parentID: null,
    title: title,
    time: PluginSessionTime(created: createdAt, updated: createdAt, archived: null),
  );
}

ObservedRootSession _observedRoot({
  required String title,
  required int updatedAt,
  required int projectionUpdatedAt,
}) => (
  sessionId: "stable-id",
  backendSessionId: "backend-id",
  projectId: "project-X",
  directory: "/projects/X",
  catalogTitle: title,
  createdAt: updatedAt,
  updatedAt: updatedAt,
  archivedAt: null,
  projectionUpdatedAt: projectionUpdatedAt,
);

class _ThrowingSessionDao extends SessionDao {
  _ThrowingSessionDao({required AppDatabase db}) : super(db);

  @override
  Future<Map<String, SessionDto>> upsertObservedRootSessions({
    required String pluginId,
    required List<ObservedRootSession> sessions,
  }) {
    throw StateError("boom");
  }
}

class _FakeNativePlugin implements NativeProjectsPluginApi {
  List<PluginSession> sessions = const [];
  Completer<void>? fetchStarted;
  Future<void>? releaseFetch;

  @override
  String get id => "fake";

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) async {
    final snapshot = List<PluginSession>.of(sessions);
    fetchStarted?.complete();
    if (releaseFetch case final release?) await release;
    return snapshot;
  }

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RacingNativePlugin extends _FakeNativePlugin {
  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    return sessions.single;
  }
}
