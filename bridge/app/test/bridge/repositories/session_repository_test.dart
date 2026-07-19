import "dart:async";

import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/models/project_not_found_exception.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionRepository", () {
    late _FakeBridgePlugin plugin;

    setUp(() {
      plugin = _FakeBridgePlugin();
    });

    test("deleteSession records a plugin-scoped tombstone and removes the stored row", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["proj-tomb"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        sessionId: "sess-tomb",
        backendSessionId: "sess-tomb",
        projectId: "proj-tomb",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );
      expect(await repository.isSessionTombstoned(sessionId: "sess-tomb"), isFalse);

      final deleted = await repository.deleteSession(sessionId: "sess-tomb");

      expect(deleted.pluginId, equals(plugin.id));
      expect(await repository.isSessionTombstoned(sessionId: "sess-tomb"), isTrue);
      expect(await db.sessionDao.getSession(sessionId: "sess-tomb"), isNull);
      expect(
        await db.sessionDao.getTombstonedSessionIds(pluginId: plugin.id),
        contains("sess-tomb"),
      );
      expect(
        await db.sessionDao.getTombstonedSessionIds(pluginId: "other"),
        isNot(contains("sess-tomb")),
      );

      await expectLater(
        repository.deleteSession(sessionId: "sess-tomb"),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 404)),
      );
    });

    test("coalesces tombstone loading and serves later lookups from memory", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final readBlock = Completer<void>();
      final sessionDao = _CountingSessionDao(tombstones: {"gone"}, readBlock: readBlock);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final first = repository.isSessionTombstoned(sessionId: "gone");
      final second = repository.isSessionTombstoned(sessionId: "live");
      await Future<void>.delayed(Duration.zero);
      expect(sessionDao.bulkReadCount, 1);

      readBlock.complete();
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(await repository.isSessionTombstoned(sessionId: "gone"), isTrue);
      expect(sessionDao.bulkReadCount, 1);
    });

    test("retries tombstone loading after a database failure", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final sessionDao = _CountingSessionDao(tombstones: {"gone"}, readBlock: null)..failuresRemaining = 1;
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await expectLater(repository.isSessionTombstoned(sessionId: "gone"), throwsStateError);
      expect(await repository.isSessionTombstoned(sessionId: "gone"), isTrue);
      expect(sessionDao.bulkReadCount, 2);
    });

    test("enrichSession merges stored archive and selected PR metadata", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/one",
        baseBranch: null,
        baseCommit: null,
        lastAgent: "agent-1",
        lastAgentModel: const AgentModel(
          providerID: "provider-1",
          modelID: "model-1",
          variant: "variant-1",
        ),
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/one",
          prNumber: 7,
          url: "https://github.com/org/repo/pull/7",
          title: "Older open PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.unknown,
          reviewDecision: PrReviewDecision.unknown,
          checkStatus: PrCheckStatus.unknown,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/one",
          prNumber: 11,
          url: "https://github.com/org/repo/pull/11",
          title: "Newest open PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 2,
          createdAt: 2,
        ),
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/one",
          prNumber: 99,
          url: "https://github.com/org/repo/pull/99",
          title: "Closed but higher number",
          state: PrState.closed,
          mergeableStatus: PrMergeableStatus.conflicting,
          reviewDecision: PrReviewDecision.changesRequested,
          checkStatus: PrCheckStatus.failure,
          lastCheckedAt: 3,
          createdAt: 3,
        ),
      );

      final result = await repository.enrichSession(
        session: const Session(
          branchName: null,
          id: "s1",
          pluginId: "fake",
          projectID: "p1",
          directory: "/tmp/project",
          parentID: null,
          title: "session",
          time: SessionTime(created: 1, updated: 2, archived: null),
          pullRequest: null,
          promptDefaults: null,
        ),
      );

      expect(result.time?.created, equals(1));
      expect(result.pluginId, equals(plugin.id));
      expect(result.time?.updated, equals(2));
      expect(result.time?.archived, isNull);
      expect(result.hasWorktree, isTrue);
      expect(result.promptDefaults?.agent, equals("agent-1"));
      expect(result.promptDefaults?.model?.providerID, equals("provider-1"));
      expect(result.promptDefaults?.model?.modelID, equals("model-1"));
      expect(result.promptDefaults?.model?.variant, equals("variant-1"));
      expect(result.pullRequest?.number, equals(11));
      expect(result.pullRequest?.state, equals(PrState.open));
    });

    test("enrichSession leaves promptDefaults null when stored defaults are all null", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "p1",
        isDedicated: false,
        createdAt: 10,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );

      final result = await repository.enrichSession(
        session: const Session(
          branchName: null,
          id: "s1",
          pluginId: "fake",
          projectID: "p1",
          directory: "/tmp/project",
          parentID: null,
          title: "session",
          time: null,
          pullRequest: null,
          promptDefaults: null,
        ),
      );

      expect(result.promptDefaults, isNull);
      expect(result.hasWorktree, isFalse);
    });

    test("enrichSessions applies stored data only to matching sessions", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: "p1",
        isDedicated: false,
        createdAt: 10,
        worktreePath: null,
        branchName: "feature/one",
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );
      await db.sessionDao.setArchived(
        sessionId: "s1",
        archivedAt: 1234,
        updatedAt: 1234,
        projectionUpdatedAt: 1234,
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/one",
          prNumber: 5,
          url: "https://github.com/org/repo/pull/5",
          title: "Only matching PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.reviewRequired,
          checkStatus: PrCheckStatus.pending,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

      final result = await repository.enrichSessions(
        sessions: const [
          Session(
            branchName: null,
            id: "s1",
            pluginId: "fake",
            projectID: "p1",
            directory: "/tmp/project",
            parentID: null,
            title: "stored",
            time: null,
            pullRequest: null,
            promptDefaults: null,
          ),
          Session(
            branchName: null,
            id: "s2",
            pluginId: "fake",
            projectID: "p1",
            directory: "/tmp/project",
            parentID: null,
            title: "unstored",
            time: SessionTime(created: 3, updated: 4, archived: null),
            pullRequest: null,
            promptDefaults: null,
          ),
        ],
      );

      expect(result, hasLength(2));
      expect(result.map((session) => session.pluginId), everyElement(plugin.id));
      expect(result[0].time?.created, equals(10));
      expect(result[0].time?.updated, equals(1234));
      expect(result[0].time?.archived, equals(1234));
      expect(result[0].pullRequest?.number, equals(5));
      expect(result[1].time?.created, equals(3));
      expect(result[1].time?.updated, equals(4));
      expect(result[1].time?.archived, isNull);
      expect(result[1].pullRequest, isNull);
    });

    test("enrichSessions retains derived project attribution after operational removal", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final derivedPlugin = _FakeDerivedPlugin(launchDirectory: "/derived", allSessions: const []);
      final operationalPlugins = {plugin.id: plugin, derivedPlugin.id: derivedPlugin};
      final repository = SessionRepository(
        operationalPlugins: operationalPlugins,
        bridgeDerivedProjectPluginIds: {derivedPlugin.id},
        enabledPluginIds: [plugin.id, derivedPlugin.id],
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
        aggregateSourceDeadline: const Duration(seconds: 1),
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["stored-native", "stored-derived"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        sessionId: "native-session",
        backendSessionId: "native-session",
        projectId: "stored-native",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );
      await db.sessionDao.insertSession(
        pluginId: derivedPlugin.id,
        sessionId: "derived-session",
        backendSessionId: "derived-session",
        projectId: "stored-derived",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/derived/.worktrees/session",
        branchName: "session",
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

      operationalPlugins.remove(derivedPlugin.id);
      final result = await repository.enrichSessions(
        sessions: const [
          Session(
            id: "native-session",
            pluginId: "fake",
            projectID: "native-reported-project",
            directory: "/native",
            parentID: null,
            title: null,
            time: null,
            pullRequest: null,
            promptDefaults: null,
          ),
          Session(
            id: "derived-session",
            pluginId: "codex",
            projectID: "/derived/.worktrees/session",
            directory: "/derived/.worktrees/session",
            parentID: null,
            title: null,
            time: null,
            pullRequest: null,
            promptDefaults: null,
          ),
        ],
      );

      expect(result[0].projectID, "native-reported-project");
      expect(result[1].projectID, "stored-derived");
    });

    test("insertStoredSession ensures project and stores prompt defaults transactionally", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await repository.insertStoredSession(
        sessionId: "s-created",
        backendSessionId: "backend-created",
        pluginId: plugin.id,
        projectId: "p-created",
        isDedicated: true,
        createdAt: 123,
        worktreePath: "/tmp/wt",
        branchName: "feature/defaults",
        baseBranch: "main",
        baseCommit: "abc123",
        agent: "agent-1",
        agentModel: const AgentModel(
          providerID: "provider-1",
          modelID: "model-1",
          variant: "variant-1",
        ),
      );

      final projects = await db.select(db.projectsTable).get();
      final row = await db.sessionDao.getSession(sessionId: "s-created");

      expect(projects.map((project) => project.projectId), equals(["p-created"]));
      expect(row, isNotNull);
      expect(row!.backendSessionId, equals("backend-created"));
      expect(row.pluginId, equals(plugin.id));
      expect(row.lastAgent, equals("agent-1"));
      expect(row.lastAgentModel?.providerID, equals("provider-1"));
      expect(row.lastAgentModel?.modelID, equals("model-1"));
      expect(row.lastAgentModel?.variant, equals("variant-1"));
      expect(row.worktreePath, equals("/tmp/wt"));
    });

    test("insertStoredSession drops the orphaned placeholder project row after re-attribution", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      // A live session.created raced ahead of the create flow: the placeholder
      // keyed the session (and a project row) to the plugin-reported worktree
      // cwd instead of the project the user opened.
      const worktree = "/repo/.worktrees/s1";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [worktree]);
      await db.sessionDao.insertSessionsIfMissing(
        pluginId: "fake",
        sessions: [
          (
            sessionId: "s1",
            backendSessionId: "s1",
            projectId: worktree,
            directory: worktree,
            createdAt: 100,
            archivedAt: null,
          ),
        ],
      );

      await repository.insertStoredSession(
        sessionId: "s1",
        backendSessionId: "s1",
        pluginId: plugin.id,
        projectId: "/repo",
        isDedicated: true,
        createdAt: 200,
        worktreePath: worktree,
        branchName: "s1",
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );

      // The session is re-attributed to the canonical project and the stale
      // worktree project row is gone — it must not surface as an empty
      // derived project card.
      final row = await db.sessionDao.getSession(sessionId: "s1");
      expect(row?.projectId, "/repo");
      final projects = await db.select(db.projectsTable).get();
      expect(projects.map((project) => project.projectId), equals(["/repo"]));
    });

    test("insertStoredSession keeps a project row that carries user-set state", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      // The placeholder happens to be keyed to a path the user renamed — a
      // real project, not junk. It must survive the cleanup even once its
      // last session is re-attributed away.
      const touched = "/repo/renamed";
      await db.projectsDao.setDisplayName(projectId: touched, displayName: "My Project", updatedAt: 100);
      await db.sessionDao.insertSessionsIfMissing(
        pluginId: "fake",
        sessions: [
          (
            sessionId: "s1",
            backendSessionId: "s1",
            projectId: touched,
            directory: touched,
            createdAt: 100,
            archivedAt: null,
          ),
        ],
      );

      await repository.insertStoredSession(
        sessionId: "s1",
        backendSessionId: "s1",
        pluginId: plugin.id,
        projectId: "/repo",
        isDedicated: false,
        createdAt: 200,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );

      final projects = await db.select(db.projectsTable).get();
      expect(projects.map((project) => project.projectId).toSet(), equals({"/repo", touched}));
    });

    test("insertStoredSession keeps a placeholder project row that other sessions still reference", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      const shared = "/repo/other";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [shared]);
      await db.sessionDao.insertSessionsIfMissing(
        pluginId: "fake",
        sessions: [
          (
            sessionId: "s1",
            backendSessionId: "s1",
            projectId: shared,
            directory: shared,
            createdAt: 100,
            archivedAt: null,
          ),
          (
            sessionId: "s-other",
            backendSessionId: "s-other",
            projectId: shared,
            directory: shared,
            createdAt: 100,
            archivedAt: null,
          ),
        ],
      );

      await repository.insertStoredSession(
        sessionId: "s1",
        backendSessionId: "s1",
        pluginId: plugin.id,
        projectId: "/repo",
        isDedicated: false,
        createdAt: 200,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );

      final projects = await db.select(db.projectsTable).get();
      expect(projects.map((project) => project.projectId).toSet(), equals({"/repo", shared}));
      expect((await db.sessionDao.getSession(sessionId: "s-other"))?.projectId, shared);
    });

    test("updatePromptDefaults writes latest nullable prompt defaults", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await repository.insertStoredSession(
        sessionId: "s-update",
        backendSessionId: "s-update",
        pluginId: plugin.id,
        projectId: "p-update",
        isDedicated: false,
        createdAt: 123,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: "old-agent",
        agentModel: const AgentModel(
          providerID: "old-provider",
          modelID: "old-model",
          variant: "old-variant",
        ),
      );

      await repository.updatePromptDefaults(
        sessionId: "s-update",
        agent: null,
        agentModel: const AgentModel(
          providerID: "new-provider",
          modelID: "new-model",
          variant: null,
        ),
      );

      final row = await db.sessionDao.getSession(sessionId: "s-update");
      expect(row, isNotNull);
      expect(row!.lastAgent, isNull);
      expect(row.lastAgentModel?.providerID, equals("new-provider"));
      expect(row.lastAgentModel?.modelID, equals("new-model"));
      expect(row.lastAgentModel?.variant, isNull);
    });

    test("renameSession delegates to plugin and maps its shared session", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        sessionId: "s1",
        backendSessionId: "backend-s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/rename",
        baseBranch: null,
        baseCommit: null,

        lastAgent: null,
        lastAgentModel: null,
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/rename",
          prNumber: 12,
          url: "https://github.com/org/repo/pull/12",
          title: "Rename PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );
      plugin.renameSessionResult = const PluginSession(
        id: "backend-s1",
        projectID: "p1",
        directory: "/tmp/worktree",
        parentID: null,
        title: "Renamed",
        time: PluginSessionTime(created: 1, updated: 2, archived: null),
      );

      final result = await repository.renameSession(sessionId: "s1", title: "Renamed");

      expect(plugin.lastRenameSessionId, equals("backend-s1"));
      expect(plugin.lastRenameSessionTitle, equals("Renamed"));
      expect(result.pluginId, equals(plugin.id));
      expect(result.title, equals("Renamed"));
      expect(result.hasWorktree, isFalse);
      expect(result.pullRequest, isNull);
    });

    test("findProjectIdForSession returns stored project id without scanning plugin", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p-stored"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        sessionId: "s-target",
        backendSessionId: "s-target",
        projectId: "p-stored",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/tmp",
        branchName: "main",
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );

      final result = await repository.findProjectIdForSession(sessionId: "s-target");

      expect(result, equals("p-stored"));
      expect(plugin.getProjectsCalls, isZero);
      expect(plugin.getSessionsCalls, isZero);
    });

    test("findProjectIdForSession keeps a missing binding missing without plugin discovery", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final result = await repository.findProjectIdForSession(sessionId: "s-target");

      expect(result, isNull);
      expect(plugin.getProjectsCalls, isZero);
      expect(plugin.getSessionsCalls, isZero);
    });

    test("createSession passes variant directly to plugin", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final cases = <SessionVariant?>[const SessionVariant(id: "low"), const SessionVariant(id: "xhigh"), null];

      for (final variant in cases) {
        await repository.createSession(
          pluginId: plugin.id,
          projectId: "/repo",
          directory: "/repo",
          parentSessionId: null,
          parts: const [PromptPart.text(text: "Ship it")],
          variant: variant,
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

        expect(plugin.lastCreateSessionVariant, equals(variant?.id));
      }
    });

    test("createSession rejects a plugin mismatch before plugin I/O", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await expectLater(
        repository.createSession(
          pluginId: "other-plugin",
          projectId: "/repo",
          directory: "/repo",
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
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 503)),
      );
      expect(plugin.createSessionCalls, isZero);
    });

    group("moved project (stable id, new live path)", () {
      test("getSessionsForProject reads stored bindings without plugin enumeration", () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        await db.projectsDao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          displayName: null,
          createdAt: 1,
          updatedAt: 1,
        );
        plugin.sessionsByWorktree = {
          "/moved/a": const [
            PluginSession(
              id: "backend-live",
              // The plugin can only echo the directory it was asked about —
              // it has no notion of the bridge's stable identifier.
              projectID: "/moved/a",
              directory: "/moved/a",
              parentID: null,
              title: "Session",
              time: null,
            ),
          ],
        };

        final repository = singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        );
        await repository.insertStoredSession(
          sessionId: "stable-live",
          backendSessionId: "backend-live",
          pluginId: plugin.id,
          projectId: "/projects/a",
          isDedicated: false,
          createdAt: 1,
          worktreePath: null,
          branchName: null,
          baseBranch: null,
          baseCommit: null,
          agent: null,
          agentModel: null,
        );

        final sessions = await repository.getSessionsForProject(
          projectId: "/projects/a",
          start: null,
          limit: null,
        );
        final binding = await db.sessionDao.getSession(sessionId: "stable-live");

        expect(plugin.lastGetSessionsWorktree, isNull);
        expect(sessions.single.id, equals("stable-live"));
        expect(sessions.single.pluginId, equals(plugin.id));
        expect(sessions.single.projectID, equals("/projects/a"));
        expect(binding?.backendSessionId, equals("backend-live"));
        expect(binding?.directory, equals("/moved/a"));
      });

      test("getCommands resolves the project id to the live directory", () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        await db.projectsDao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          displayName: null,
          createdAt: 1,
          updatedAt: 1,
        );

        final repository = singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        );

        await repository.getCommands(projectId: "/projects/a", pluginId: plugin.id);
        expect(plugin.lastGetCommandsProjectId, equals("/moved/a"));

        // Null/blank keeps the plugin's own fallback untouched.
        await repository.getCommands(projectId: "  ", pluginId: plugin.id);
        expect(plugin.lastGetCommandsProjectId, isNull);
      });

      test("getProjectPath returns the stored live directory without probing the plugin", () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        await db.projectsDao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          displayName: null,
          createdAt: 1,
          updatedAt: 1,
        );

        final repository = singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        );

        final path = await repository.getProjectPath(projectId: "/projects/a");

        expect(path, equals("/moved/a"));
        expect(plugin.lastGetProjectDirectory, isNull);
      });

      test("resolveProjectDirectory rejects an unknown project id", () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final repository = singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        );

        await expectLater(
          () => repository.resolveProjectDirectory(projectId: "/projects/a"),
          throwsA(isA<ProjectNotFoundException>()),
        );
      });
    });

    test("sendPrompt and sendCommand pass variant directly to plugin", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await repository.insertStoredSession(
        sessionId: "stable-s1",
        backendSessionId: "backend-s1",
        pluginId: plugin.id,
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

      final cases = <SessionVariant?>[const SessionVariant(id: "low"), const SessionVariant(id: "xhigh"), null];

      for (final variant in cases) {
        await repository.sendPrompt(
          sessionId: "stable-s1",
          parts: const [PromptPart.text(text: "Prompt")],
          variant: variant,
          agent: null,
          model: null,
        );
        expect(plugin.lastSendPromptVariant, equals(variant?.id));
        expect(plugin.lastSendPromptSessionId, equals("backend-s1"));

        await repository.sendCommand(
          sessionId: "stable-s1",
          command: "review",
          arguments: "Prompt",
          variant: variant,
          agent: null,
          model: null,
        );
        expect(plugin.lastSendCommandVariant, equals(variant?.id));
        expect(plugin.lastSendCommandSessionId, equals("backend-s1"));
      }
    });

    test("session operations reject missing and mismatched bindings before plugin I/O", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await expectLater(
        repository.sendPrompt(
          sessionId: "missing",
          parts: const [],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 404)),
      );
      await repository.insertStoredSession(
        sessionId: "wrong-plugin",
        backendSessionId: "backend-wrong-plugin",
        pluginId: "other-plugin",
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
      await expectLater(
        repository.sendPrompt(
          sessionId: "wrong-plugin",
          parts: const [],
          variant: null,
          agent: null,
          model: null,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 503)),
      );
      expect(plugin.sendPromptCalls, isZero);
    });

    test("messages and statuses map backend identities back to stable session ids", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await repository.insertStoredSession(
        sessionId: "stable-s1",
        backendSessionId: "backend-s1",
        pluginId: plugin.id,
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
      plugin.messagesResult = const [
        PluginMessageWithParts(
          info: PluginMessageUser(id: "message-1", sessionID: "backend-s1", agent: null, time: null),
          parts: [
            PluginMessagePart(
              id: "part-1",
              sessionID: "backend-s1",
              messageID: "message-1",
              type: PluginMessagePartType.text,
              text: "hello",
              tool: null,
              state: null,
              prompt: null,
              description: null,
              agent: null,
              agentName: null,
              attempt: null,
              retryError: null,
            ),
          ],
        ),
      ];
      plugin.sessionStatusesResult = const {
        "backend-s1": PluginSessionStatus.busy(),
        "unknown-backend": PluginSessionStatus.idle(),
      };

      final messages = await repository.getSessionMessages(sessionId: "stable-s1");
      final statuses = await repository.getSessionStatuses();

      expect(plugin.lastGetMessagesSessionId, equals("backend-s1"));
      expect(messages.single.info.sessionID, equals("stable-s1"));
      expect(messages.single.parts.single.sessionID, equals("stable-s1"));
      expect(statuses.statuses, equals({"stable-s1": const SessionStatus.busy()}));
    });

    test("unknown sessions reject message and abort operations", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await expectLater(
        repository.getSessionMessages(sessionId: "unknown"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      await expectLater(
        repository.abortSession(sessionId: "unknown"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(plugin.lastGetMessagesSessionId, isNull);
      expect(plugin.lastAbortSessionId, isNull);
    });

    test("getProjectActivitySummaries hydrates an active root without a catalog binding", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      const directory = "/projects/active";
      plugin
        ..activitySummaries = const [
          PluginProjectActivitySummary(
            id: directory,
            activeSessions: [
              PluginActiveSession(id: "backend-root", awaitingInput: true),
            ],
          ),
        ]
        ..sessionsByWorktree = const {
          directory: [
            PluginSession(
              id: "backend-root",
              projectID: directory,
              directory: directory,
              parentID: null,
              title: "Active root",
              time: PluginSessionTime(created: 1, updated: 2, archived: null),
            ),
          ],
        };
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final bindingCommit = repository.bindingCommits.first;
      final summaries = await repository.getProjectActivitySummaries();
      final commit = await bindingCommit;

      final active = summaries.single.activeSessions.single;
      expect(active.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(active.awaitingInput, isTrue);
      expect(plugin.lastGetProjectDirectory, directory);
      expect(plugin.lastGetSessionsWorktree, directory);
      expect(commit.pluginId, plugin.id);
      expect(commit.backendSessionIds, ["backend-root"]);
      expect(
        (await db.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "backend-root",
        ))?.sessionId,
        active.id,
      );
    });

    test("active native-root hydration reuses the normalized-path catalog row", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      const directory = "/projects/shared";
      const nativeProjectId = "native-project-id";
      plugin
        ..activitySummaries = const [
          PluginProjectActivitySummary(
            id: directory,
            activeSessions: [PluginActiveSession(id: "backend-root", awaitingInput: true)],
          ),
        ]
        ..projectsByDirectory = const {
          directory: PluginProject(id: nativeProjectId, directory: "$directory/."),
        }
        ..sessionsByWorktree = const {
          "$directory/.": [
            PluginSession(
              id: "backend-root",
              projectID: nativeProjectId,
              directory: "$directory/.",
              parentID: null,
              title: "Active root",
              time: PluginSessionTime(created: 1, updated: 2, archived: null),
            ),
          ],
        };
      await db.projectsDao.recordOpenedProject(
        projectId: directory,
        path: directory,
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final summaries = await repository.getProjectActivitySummaries();

      expect(summaries.single.id, directory);
      expect(
        (await db.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "backend-root",
        ))?.projectId,
        directory,
      );
      expect((await db.projectsDao.getAllProjects()).map((project) => project.projectId), [directory]);
    });

    test("active native-root hydration atomically rechecks identity against catalog import", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      const directory = "/projects/racing-shared";
      const normalizedAlias = "$directory/.";
      const nativeProjectId = "native-project-id";
      const importedProjectId = "catalog-project-id";
      plugin
        ..activitySummaries = const [
          PluginProjectActivitySummary(
            id: directory,
            activeSessions: [PluginActiveSession(id: "backend-root-one", awaitingInput: true)],
          ),
          PluginProjectActivitySummary(
            id: normalizedAlias,
            activeSessions: [PluginActiveSession(id: "backend-root-two", awaitingInput: false)],
          ),
        ]
        ..projectsByDirectory = const {
          directory: PluginProject(id: nativeProjectId, directory: normalizedAlias),
          normalizedAlias: PluginProject(id: nativeProjectId, directory: normalizedAlias),
        }
        ..sessionsByWorktree = const {
          normalizedAlias: [
            PluginSession(
              id: "backend-root-one",
              projectID: nativeProjectId,
              directory: normalizedAlias,
              parentID: null,
              title: "Active root one",
              time: PluginSessionTime(created: 1, updated: 2, archived: null),
            ),
            PluginSession(
              id: "backend-root-two",
              projectID: nativeProjectId,
              directory: normalizedAlias,
              parentID: null,
              title: "Active root two",
              time: PluginSessionTime(created: 3, updated: 4, archived: null),
            ),
          ],
        };
      final projectsDao = _BlockingSnapshotProjectsDao(database: db);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final hydration = repository.getProjectActivitySummaries();
      await projectsDao.snapshotTaken.future;
      await db.projectsDao.recordOpenedProject(
        projectId: importedProjectId,
        path: directory,
        displayName: null,
        createdAt: 1,
        updatedAt: 2,
      );
      projectsDao.releaseSnapshot.complete();

      final summaries = await hydration;
      final projects = await db.projectsDao.getAllProjects();
      final bindings = await db.sessionDao.getSessionsByBackendIds(
        pluginId: plugin.id,
        backendSessionIds: const ["backend-root-one", "backend-root-two"],
      );

      expect(projects.map((project) => project.projectId), [importedProjectId]);
      expect(summaries.single.id, importedProjectId);
      expect(summaries.single.activeSessions, hasLength(2));
      expect(bindings.keys, {"backend-root-one", "backend-root-two"});
      expect(bindings.values.map((binding) => binding.projectId), everyElement(importedProjectId));
      expect(plugin.getSessionsCalls, 1, reason: "normalized summaries must hydrate their shared project once");
    });

    test("getProjectActivitySummaries isolates a failed active-root hydration", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      const failedDirectory = "/projects/failed";
      const healthyDirectory = "/projects/healthy";
      plugin
        ..activitySummaries = const [
          PluginProjectActivitySummary(
            id: failedDirectory,
            activeSessions: [PluginActiveSession(id: "failed-root", awaitingInput: true)],
          ),
          PluginProjectActivitySummary(
            id: healthyDirectory,
            activeSessions: [PluginActiveSession(id: "healthy-root", awaitingInput: true)],
          ),
        ]
        ..failingProjectIds = {failedDirectory}
        ..sessionsByWorktree = const {
          healthyDirectory: [
            PluginSession(
              id: "healthy-root",
              projectID: healthyDirectory,
              directory: healthyDirectory,
              parentID: null,
              title: "Healthy root",
              time: PluginSessionTime(created: 1, updated: 2, archived: null),
            ),
          ],
        };
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final summaries = await repository.getProjectActivitySummaries();

      expect(summaries.map((summary) => summary.id), isNot(contains(failedDirectory)));
      final healthy = summaries.singleWhere((summary) => summary.id == healthyDirectory).activeSessions.single;
      expect(healthy.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(healthy.awaitingInput, isTrue);
    });
  });

  group("SessionRepository (bridge-derived)", () {
    PluginSession pluginSession(String directory, {required String id}) => PluginSession(
      id: id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: null,
      time: const PluginSessionTime(created: 1, updated: 1, archived: null),
    );

    Future<void> recordWorktreeSession(
      AppDatabase db, {
      required String parent,
      required String worktree,
      required String sessionId,
    }) async {
      // Mirror what SessionCreationService persists: the session's owning
      // project plus the worktree the bridge created for it.
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);
      await db.sessionDao.insertSession(
        sessionId: sessionId,
        backendSessionId: sessionId,
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

    test("getSessionsForProject lists the durable worktree session under its parent project", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      final plugin = _FakeDerivedPlugin(
        launchDirectory: parent,
        allSessions: [
          pluginSession(parent, id: "s1"),
          pluginSession(worktree, id: "w1"),
        ],
      );
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "w1");

      final sessions = await repository.getSessionsForProject(projectId: parent, start: null, limit: null);

      expect(sessions.map((s) => s.id).toSet(), {"w1"});
      // Enrichment adopts the stored attribution as projectID (the plugin
      // reported the worktree cwd), so live created/updated events for this
      // session are not dropped by the parent project's session list. The
      // directory stays the session's real cwd.
      final worktreeSession = sessions.singleWhere((s) => s.id == "w1");
      expect(worktreeSession.projectID, parent);
      expect(worktreeSession.directory, worktree);
      expect(plugin.receivedKnownDirectories, isNull);
    });

    test("findProjectIdForSession resolves a recorded worktree session to its parent via its stored row", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      // The bridge recorded a1 under its parent project at creation; the stored
      // row is authoritative even though the plugin reports the session under
      // its worktree cwd.
      final plugin = _FakeDerivedPlugin(
        launchDirectory: parent,
        allSessions: [pluginSession(worktree, id: "a1")],
      );
      final repository = singlePluginSessionRepository(
        unseenCalculator: const SessionUnseenCalculator(),
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
      );
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "a1");

      final result = await repository.findProjectIdForSession(sessionId: "a1");

      expect(result, equals(parent));
    });

    test("findProjectIdForSession keeps a rowless derived session missing", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const directory = "/tmp/proj/beta";
      final plugin = _FakeDerivedPlugin(
        launchDirectory: "/tmp/proj/alpha",
        allSessions: [pluginSession(directory, id: "b1")],
      );
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final result = await repository.findProjectIdForSession(sessionId: "b1");

      expect(result, isNull);
      expect(plugin.listAllSessionsCalls, isZero);
    });

    test("sendPrompt/sendCommand/getSessionMessages prime a derived plugin with the stored directory", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      final plugin = _FakeDerivedPlugin(launchDirectory: parent, allSessions: const []);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      // One dedicated-worktree session and one plain in-project session.
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "w1");
      await db.sessionDao.insertSession(
        sessionId: "p1",
        backendSessionId: "p1",
        projectId: parent,
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "codex",
      );

      // The worktree session primes with its worktree path...
      await repository.sendPrompt(sessionId: "w1", parts: const [], variant: null, agent: null, model: null);
      expect(plugin.primedDirectories.last, (sessionId: "w1", directory: worktree));

      // ...a plain session primes with the owning project directory...
      await repository.getSessionMessages(sessionId: "p1");
      expect(plugin.primedDirectories.last, (sessionId: "p1", directory: parent));

      await repository.sendCommand(
        sessionId: "w1",
        command: "review",
        arguments: "",
        variant: null,
        agent: null,
        model: null,
      );
      expect(plugin.primedDirectories.last, (sessionId: "w1", directory: worktree));

      // A rowless session is rejected before plugin access.
      final primesBefore = plugin.primedDirectories.length;
      final sendsBefore = plugin.sendPromptCalls;
      await expectLater(
        repository.sendPrompt(sessionId: "ghost", parts: const [], variant: null, agent: null, model: null),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 404)),
      );
      expect(plugin.primedDirectories.length, primesBefore);
      expect(plugin.sendPromptCalls, sendsBefore);
    });

    test("getProjectActivitySummaries maps stored sessions and drops rowless activity", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      final plugin = _FakeDerivedPlugin(launchDirectory: parent, allSessions: const []);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "w1");
      // The plugin groups the active worktree session under its own cwd (the
      // worktree) — exactly what the ACP plugin reports — plus a rowless
      // session under its own directory.
      plugin.activitySummaries = const [
        PluginProjectActivitySummary(
          id: worktree,
          activeSessions: [
            PluginActiveSession(
              id: "w1",
              mainAgentRunning: true,
              awaitingInput: false,
              isRetrying: false,
              childSessionIds: [],
            ),
          ],
        ),
        PluginProjectActivitySummary(
          id: "/tmp/proj/beta",
          activeSessions: [
            PluginActiveSession(
              id: "b1",
              mainAgentRunning: false,
              awaitingInput: true,
              isRetrying: false,
              childSessionIds: [],
            ),
          ],
        ),
      ];

      final summaries = await repository.getProjectActivitySummaries();

      // The worktree session's badge lands on the stored parent project — the
      // id the phone's project list actually shows.
      final byId = {for (final s in summaries) s.id: s};
      expect(byId.keys, [parent]);
      expect(byId.keys, isNot(contains(worktree)));
      expect(byId[parent]!.activeSessions.single.id, "w1");
      expect(byId[parent]!.activeSessions.single.mainAgentRunning, isTrue);
    });

    test("getProjectActivitySummaries excludes tombstoned backend sessions", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const project = "/tmp/proj/alpha";
      final plugin = _FakeDerivedPlugin(launchDirectory: project, allSessions: const [])
        ..activitySummaries = const [
          PluginProjectActivitySummary(
            id: project,
            activeSessions: [
              PluginActiveSession(
                id: "gone",
                mainAgentRunning: true,
                awaitingInput: false,
                isRetrying: false,
                childSessionIds: [],
              ),
            ],
          ),
        ];
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone",
        pluginId: plugin.id,
        deletedAt: 1,
      );

      expect(await repository.getProjectActivitySummaries(), isEmpty);
    });

    test("setSessionTitleIfStored makes a derived title win over enumeration", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      final plugin = _FakeDerivedPlugin(
        launchDirectory: parent,
        // The backend keeps reporting its own auto-generated title — a rename
        // never reaches it (ACP has no rename RPC).
        allSessions: [
          const PluginSession(
            id: "s1",
            projectID: parent,
            directory: parent,
            parentID: null,
            title: "Backend auto-title",
            time: PluginSessionTime(created: 1, updated: 1, archived: null),
          ),
        ],
      );
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);
      await db.sessionDao.insertSession(
        sessionId: "s1",
        backendSessionId: "s1",
        projectId: parent,
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "codex",
      );

      expect(
        await repository.setSessionTitleIfStored(sessionId: "s1", title: "My rename"),
        isTrue,
      );

      // The next enumeration keeps serving the rename, not the backend's
      // auto-title: the stored copy wins for derived plugins.
      final sessions = await repository.getSessionsForProject(projectId: parent, start: null, limit: null);
      expect(sessions.single.title, "My rename");
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.title, "My rename");
    });

    test("renameSession rejects a tombstoned session before plugin access", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final plugin = _FakeDerivedPlugin(
        launchDirectory: "/repo",
        allSessions: const [],
      );
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone",
        pluginId: plugin.id,
        deletedAt: 1,
      );

      await expectLater(
        repository.renameSession(sessionId: "gone", title: "Resurrected"),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );
      expect(plugin.lastRenameSessionId, isNull);

      final guardedOperations = <Future<void> Function()>[
        () => repository.sendCommand(
          sessionId: "gone",
          command: "test",
          arguments: "",
          variant: null,
          agent: null,
          model: null,
        ),
        () => repository.sendPrompt(
          sessionId: "gone",
          parts: const [],
          variant: null,
          agent: null,
          model: null,
        ),
        () async => repository.getSessionMessages(sessionId: "gone"),
        () => repository.notifySessionArchived(sessionId: "gone"),
        () => repository.abortSession(sessionId: "gone"),
        () async => repository.getChildSessions(sessionId: "gone"),
      ];
      for (final operation in guardedOperations) {
        await expectLater(
          operation(),
          throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
        );
      }
    });

    test("getChildSessions serves durable history without backend discovery", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final plugin = _FakeDerivedPlugin(launchDirectory: "/repo", allSessions: const [])
        ..childSessions = const [
          PluginSession(
            id: "new-backend-child",
            projectID: "/repo",
            directory: "/repo/new-child",
            parentID: "live-parent",
            title: "New child",
            time: PluginSessionTime(created: 3, updated: 4, archived: null),
          ),
        ];
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      await db.sessionDao.insertSession(
        sessionId: "stable-parent",
        backendSessionId: "live-parent",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: plugin.id,
      );
      await db.sessionDao.insertObservedChild(
        sessionId: "stable-child",
        backendSessionId: "live-child",
        projectId: "/repo",
        parentSessionId: "stable-parent",
        directory: "/repo",
        catalogTitle: "Child",
        archivedAt: null,
        createdAt: 2,
        updatedAt: 2,
        projectionUpdatedAt: 2,
        pluginId: plugin.id,
      );

      final children = await repository.getChildSessions(sessionId: "stable-parent");

      expect(plugin.lastGetChildSessionsParentId, isNull);
      expect(children.map((session) => session.id), ["stable-child"]);
      expect(
        await db.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "new-backend-child",
        ),
        isNull,
      );
      final childDetail = await repository.getSessionForProject(
        projectId: "/repo",
        sessionId: "stable-child",
      );
      expect(childDetail?.id, "stable-child");
      expect(childDetail?.parentID, "stable-parent");
      expect(
        await repository.getSessionForProject(
          projectId: "/other",
          sessionId: "stable-child",
        ),
        isNull,
      );

      plugin.getChildSessionsError = const PluginOperationException(
        "getChildSessions",
        statusCode: 503,
        message: "backend unavailable",
      );
      final offlineChildren = await repository.getChildSessions(sessionId: "stable-parent");
      expect(offlineChildren.map((session) => session.id), ["stable-child"]);
    });

    test("deleteSession rejects a rowless session without plugin discovery", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final plugin = _FakeDerivedPlugin(
        launchDirectory: "/repo",
        allSessions: const [],
      )..listAllSessionsError = StateError("enumeration failed");
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await expectLater(
        repository.deleteSession(sessionId: "rowless"),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 404)),
      );
      expect(plugin.deleteCalls, isZero);
      expect(plugin.listAllSessionsCalls, isZero);
    });

    test("deleteSession tombstones the stored backend identity", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final plugin = _FakeDerivedPlugin(launchDirectory: "/repo", allSessions: const []);
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await repository.insertStoredSession(
        sessionId: "sesori-id",
        backendSessionId: "backend-id",
        pluginId: plugin.id,
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
      await repository.deleteSession(sessionId: "sesori-id");

      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "backend-id", pluginId: plugin.id), isTrue);
      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "sesori-id", pluginId: plugin.id), isFalse);
    });

    test("tombstones do not enumerate or manufacture catalog sessions", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      final plugin = _FakeDerivedPlugin(
        launchDirectory: parent,
        // The backend has no session deletion, so it keeps enumerating the
        // deleted session forever.
        allSessions: [
          pluginSession(parent, id: "deleted-s"),
          pluginSession(parent, id: "kept-s"),
        ],
      );
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "deleted-s",
        pluginId: "codex",
        deletedAt: 1,
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);

      final sessions = await repository.getSessionsForProject(projectId: parent, start: null, limit: null);
      expect(sessions, isEmpty);

      expect(await repository.findProjectIdForSession(sessionId: "deleted-s"), isNull);
      expect(await repository.findProjectIdForSession(sessionId: "kept-s"), isNull);
      expect(plugin.listAllSessionsCalls, 0);
    });

    test("getSessionsForProject rejects a worktree path without a durable project row", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      final plugin = _FakeDerivedPlugin(
        launchDirectory: parent,
        allSessions: [pluginSession(worktree, id: "w1")],
      );
      final repository = singlePluginSessionRepository(
        unseenCalculator: const SessionUnseenCalculator(),
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
      );
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "w1");

      await expectLater(
        repository.getSessionsForProject(projectId: worktree, start: null, limit: null),
        throwsA(isA<ProjectNotFoundException>()),
      );
    });
  });

  group("the branch a session's workspace is on", () {
    late _FakeBridgePlugin plugin;

    setUp(() {
      plugin = _FakeBridgePlugin();
    });

    /// A project whose sessions the plugin reports from [directory].
    Future<SessionRepository> repositoryListing({
      required AppDatabase db,
      required String directory,
      required List<String> sessionIds,
    }) async {
      await db.projectsDao.recordOpenedProject(
        projectId: directory,
        path: directory,
        createdAt: 1,
        updatedAt: 1,
      );
      plugin.sessionsByWorktree = {
        directory: [
          for (final id in sessionIds)
            PluginSession(
              id: id,
              projectID: directory,
              directory: directory,
              parentID: null,
              title: "Session $id",
              time: null,
            ),
        ],
      };
      return SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
    }

    /// A stored row for a plugin-reported session in [directory], carrying the
    /// branch the bridge recorded for it.
    Future<void> insertRowWithBranch({
      required AppDatabase db,
      required String sessionId,
      required String directory,
      required String branchName,
    }) {
      return db.sessionDao.insertSession(
        sessionId: sessionId,
        backendSessionId: sessionId,
        projectId: directory,
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: branchName,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: plugin.id,
      );
    }

    test("names the branch a worktree session was cut on", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = await repositoryListing(db: db, directory: "/repo", sessionIds: ["s1"]);
      await repository.insertStoredSession(
        sessionId: "s1",
        backendSessionId: "s1",
        pluginId: plugin.id,
        projectId: "/repo",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/repo/.worktrees/s1",
        branchName: "sesori/s1",
        baseBranch: "main",
        baseCommit: null,
        agent: null,
        agentModel: null,
      );

      final sessions = await repository.getSessionsForProject(projectId: "/repo", start: null, limit: null);

      expect(sessions.single.branchName, equals("sesori/s1"));
    });

    test("leaves the branch unknown when the row records none", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = await repositoryListing(db: db, directory: "/repo", sessionIds: ["s1"]);

      final sessions = await repository.getSessionsForProject(projectId: "/repo", start: null, limit: null);

      expect(sessions.single.branchName, isNull);
    });

    test("enrichSessions names the stored branch for a plugin session, which carries none of its own", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = await repositoryListing(db: db, directory: "/repo", sessionIds: const []);
      await insertRowWithBranch(db: db, sessionId: "s1", directory: "/repo", branchName: "main");

      final enriched = await repository.enrichPluginSession(
        pluginSession: const PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Session s1",
          time: null,
        ),
      );

      expect(enriched.branchName, equals("main"));
    });

    test("names the branch for a live session event, which carries none of its own", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = await repositoryListing(db: db, directory: "/repo", sessionIds: const []);
      await insertRowWithBranch(db: db, sessionId: "s1", directory: "/repo", branchName: "main");

      final enriched = await repository.getCatalogSession(sessionId: "s1");

      expect(enriched?.branchName, equals("main"));
    });

    test("shows every session sharing a branch the PR open on it", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = await repositoryListing(db: db, directory: "/repo", sessionIds: ["s1", "s2"]);
      for (final sessionId in ["s1", "s2"]) {
        await insertRowWithBranch(
          db: db,
          sessionId: sessionId,
          directory: "/repo",
          branchName: "ui/session-list-item",
        );
      }
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "/repo",
          branchName: "ui/session-list-item",
          prNumber: 482,
          url: "https://github.com/org/repo/pull/482",
          title: "Redesign the session list item",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.approved,
          checkStatus: PrCheckStatus.success,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

      // The PR-to-session join runs in SQL over the stored branch_name.
      final sessions = await repository.getSessionsForProject(projectId: "/repo", start: null, limit: null);

      expect(sessions, hasLength(2));
      expect(sessions.map((session) => session.pullRequest?.number), everyElement(equals(482)));
    });
  });
}

class _FakeBridgePlugin implements NativeProjectsPluginApi {
  List<PluginProject> projectsResult = const [];
  List<PluginSession> sessionsResult = const [];
  Map<String, List<PluginSession>> sessionsByWorktree = const {};
  List<PluginMessageWithParts> messagesResult = const [];
  Map<String, PluginSessionStatus> sessionStatusesResult = const {};
  PluginSession createSessionResult = const PluginSession(
    id: "created-session",
    projectID: "/repo",
    directory: "/repo",
    parentID: null,
    title: null,
    time: null,
  );
  PluginSession? renameSessionResult;
  String? lastRenameSessionId;
  String? lastRenameSessionTitle;
  String? lastCreateSessionVariant;
  int createSessionCalls = 0;
  String? lastSendPromptVariant;
  String? lastSendPromptSessionId;
  String? lastSendCommandVariant;
  String? lastSendCommandSessionId;
  String? lastGetMessagesSessionId;
  String? lastGetSessionsWorktree;
  String? lastGetCommandsProjectId;
  String? lastGetProjectDirectory;
  int getProjectsCalls = 0;
  int getSessionsCalls = 0;
  int sendPromptCalls = 0;
  String? lastAbortSessionId;
  List<PluginProjectActivitySummary> activitySummaries = const [];
  Set<String> failingProjectIds = const {};
  Map<String, PluginProject> projectsByDirectory = const {};

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<PluginProject>> getProjects() async {
    getProjectsCalls++;
    return projectsResult;
  }

  @override
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit}) async {
    getSessionsCalls++;
    lastGetSessionsWorktree = worktree;
    return sessionsByWorktree[worktree] ?? sessionsResult;
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    lastGetCommandsProjectId = projectId;
    return const [];
  }

  @override
  Future<PluginProject> getProject(String projectId) async {
    lastGetProjectDirectory = projectId;
    if (failingProjectIds.contains(projectId)) throw StateError("project unavailable");
    return projectsByDirectory[projectId] ?? PluginProject(id: projectId, directory: projectId);
  }

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    lastRenameSessionId = sessionId;
    lastRenameSessionTitle = title;
    return renameSessionResult!;
  }

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    createSessionCalls++;
    lastCreateSessionVariant = variant?.id;
    return createSessionResult;
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    sendPromptCalls++;
    lastSendPromptSessionId = sessionId;
    lastSendPromptVariant = variant?.id;
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    lastSendCommandSessionId = sessionId;
    lastSendCommandVariant = variant?.id;
  }

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    lastGetMessagesSessionId = sessionId;
    return messagesResult;
  }

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => sessionStatusesResult;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => activitySummaries;

  @override
  Future<void> abortSession({required String sessionId}) async {
    lastAbortSessionId = sessionId;
  }

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingSessionDao implements SessionDao {
  final Set<String> tombstones;
  final Completer<void>? readBlock;
  int bulkReadCount = 0;
  int failuresRemaining = 0;

  _CountingSessionDao({required this.tombstones, required this.readBlock});

  @override
  Future<Set<String>> getTombstonedSessionIds({required String pluginId}) async {
    bulkReadCount++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError("tombstone load failed");
    }
    if (readBlock case final block?) {
      await block.future;
    }
    return Set<String>.of(tombstones);
  }

  @override
  Future<SessionDto?> getSession({required String sessionId}) async {
    return SessionDto(
      sessionId: sessionId,
      backendSessionId: sessionId,
      projectId: "project",
      parentSessionId: null,
      directory: "/project",
      worktreePath: null,
      branchName: null,
      isDedicated: false,
      archivedAt: null,
      baseBranch: null,
      baseCommit: null,
      lastAgent: null,
      lastAgentModel: null,
      createdAt: 1,
      updatedAt: 1,
      projectionUpdatedAt: 1,
      lastActivityAt: null,
      lastSeenAt: null,
      lastUserMessageAt: null,
      pluginId: "fake",
      title: null,
      catalogTitle: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BlockingSnapshotProjectsDao extends ProjectsDao {
  _BlockingSnapshotProjectsDao({required AppDatabase database}) : super(database);

  final Completer<void> snapshotTaken = Completer<void>();
  final Completer<void> releaseSnapshot = Completer<void>();

  @override
  Future<List<ProjectDto>> getAllProjects() async {
    final projects = await super.getAllProjects();
    if (!snapshotTaken.isCompleted) {
      snapshotTaken.complete();
      await releaseSnapshot.future;
    }
    return projects;
  }
}

/// A derive-style plugin (Codex/ACP shaped): reports every session through
/// [BridgeDerivedProjectsPluginApi.listAllSessions]. `id` is "codex" so the
/// repository's stored-attribution lookup
/// (`getSessionProjectPaths(pluginId: ...)`) matches the seeded session rows.
class _FakeDerivedPlugin implements BridgeDerivedProjectsPluginApi {
  _FakeDerivedPlugin({required this.launchDirectory, required this.allSessions});

  @override
  final String launchDirectory;

  List<PluginSession> allSessions;
  String? lastRenameSessionId;
  List<PluginSession> childSessions = const [];
  Object? getChildSessionsError;
  Object? listAllSessionsError;
  int deleteCalls = 0;
  int listAllSessionsCalls = 0;
  int sendPromptCalls = 0;
  String? lastGetChildSessionsParentId;

  /// The hint set received on the most recent [listAllSessions] call.
  Set<String>? receivedKnownDirectories;

  /// Every stored-directory prime the bridge fed this plugin, in order.
  final List<({String sessionId, String directory})> primedDirectories = [];

  /// Configurable activity summaries (the plugin's own grouping — for a
  /// worktree session that is the worktree cwd).
  List<PluginProjectActivitySummary> activitySummaries = const [];

  @override
  String get id => "codex";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    listAllSessionsCalls++;
    if (listAllSessionsError case final error?) throw error;
    receivedKnownDirectories = knownDirectories;
    return allSessions;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deleteCalls++;
  }

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {
    primedDirectories.add((sessionId: sessionId, directory: directory));
  }

  /// Echo-only rename, mirroring the ACP contract (no backend rename RPC).
  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    lastRenameSessionId = sessionId;
    return PluginSession(
      id: sessionId,
      projectID: launchDirectory,
      directory: launchDirectory,
      parentID: null,
      title: title,
      time: null,
    );
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async {
    lastGetChildSessionsParentId = sessionId;
    if (getChildSessionsError case final error?) throw error;
    return childSessions;
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => activitySummaries;

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    sendPromptCalls++;
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
