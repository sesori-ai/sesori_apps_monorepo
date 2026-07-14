import "dart:async";

import "package:drift/drift.dart" hide isNotNull, isNull;
import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/models/project_not_found_exception.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
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
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["proj-tomb"]);
      await db.sessionDao.insertSession(
        pluginId: plugin.id,
        sessionId: "sess-tomb",
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

      // Re-deleting the rowless session remains idempotent.
      await repository.deleteSession(sessionId: "sess-tomb");
      expect(
        await db.sessionDao.getTombstonedSessionIds(pluginId: plugin.id),
        contains("sess-tomb"),
      );
    });

    test("coalesces tombstone loading and serves later lookups from memory", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final readBlock = Completer<void>();
      final sessionDao = _CountingSessionDao(tombstones: {"gone"}, readBlock: readBlock);
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
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
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await expectLater(repository.isSessionTombstoned(sessionId: "gone"), throwsStateError);
      expect(await repository.isSessionTombstoned(sessionId: "gone"), isTrue);
      expect(sessionDao.bulkReadCount, 2);
    });

    test("enrichSession merges stored archive and selected PR metadata", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
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
          id: "s1",
          pluginId: "fake",
          projectID: "p1",
          directory: "/tmp/project",
          parentID: null,
          title: "session",
          time: SessionTime(created: 1, updated: 2, archived: null),
          summary: null,
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

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
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
          id: "s1",
          pluginId: "fake",
          projectID: "p1",
          directory: "/tmp/project",
          parentID: null,
          title: "session",
          time: null,
          summary: null,
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

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
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
      await db.sessionDao.setArchived(sessionId: "s1", archivedAt: 1234);
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
            id: "s1",
            pluginId: "fake",
            projectID: "p1",
            directory: "/tmp/project",
            parentID: null,
            title: "stored",
            time: null,
            summary: null,
            pullRequest: null,
            promptDefaults: null,
          ),
          Session(
            id: "s2",
            pluginId: "fake",
            projectID: "p1",
            directory: "/tmp/project",
            parentID: null,
            title: "unstored",
            time: SessionTime(created: 3, updated: 4, archived: null),
            summary: null,
            pullRequest: null,
            promptDefaults: null,
          ),
        ],
      );

      expect(result, hasLength(2));
      expect(result.map((session) => session.pluginId), everyElement(plugin.id));
      expect(result[0].time?.created, equals(10));
      expect(result[0].time?.updated, equals(10));
      expect(result[0].time?.archived, equals(1234));
      expect(result[0].pullRequest?.number, equals(5));
      expect(result[1].time?.created, equals(3));
      expect(result[1].time?.updated, equals(4));
      expect(result[1].time?.archived, isNull);
      expect(result[1].pullRequest, isNull);
    });

    test("insertStoredSession ensures project and stores prompt defaults transactionally", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await repository.insertStoredSession(
        sessionId: "s-created",
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
      expect(row!.lastAgent, equals("agent-1"));
      expect(row.lastAgentModel?.providerID, equals("provider-1"));
      expect(row.lastAgentModel?.modelID, equals("model-1"));
      expect(row.lastAgentModel?.variant, equals("variant-1"));
      expect(row.worktreePath, equals("/tmp/wt"));
    });

    test("insertStoredSession drops the orphaned placeholder project row after re-attribution", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      // A live session.created raced ahead of the create flow: the placeholder
      // keyed the session (and a project row) to the plugin-reported worktree
      // cwd instead of the project the user opened.
      const worktree = "/repo/.worktrees/s1";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [worktree]);
      await db.sessionDao.insertSessionsIfMissing(
        pluginId: "fake",
        sessions: [(sessionId: "s1", projectId: worktree, createdAt: 100, archivedAt: null)],
      );

      await repository.insertStoredSession(
        sessionId: "s1",
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

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      // The placeholder happens to be keyed to a path the user renamed — a
      // real project, not junk. It must survive the cleanup even once its
      // last session is re-attributed away.
      const touched = "/repo/renamed";
      await db.projectsDao.setDisplayName(projectId: touched, displayName: "My Project");
      await db.sessionDao.insertSessionsIfMissing(
        pluginId: "fake",
        sessions: [(sessionId: "s1", projectId: touched, createdAt: 100, archivedAt: null)],
      );

      await repository.insertStoredSession(
        sessionId: "s1",
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

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      const shared = "/repo/other";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [shared]);
      await db.sessionDao.insertSessionsIfMissing(
        pluginId: "fake",
        sessions: [
          (sessionId: "s1", projectId: shared, createdAt: 100, archivedAt: null),
          (sessionId: "s-other", projectId: shared, createdAt: 100, archivedAt: null),
        ],
      );

      await repository.insertStoredSession(
        sessionId: "s1",
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

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await repository.insertStoredSession(
        sessionId: "s-update",
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

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
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
        id: "s1",
        projectID: "p1",
        directory: "/tmp/worktree",
        parentID: null,
        title: "Renamed",
        time: PluginSessionTime(created: 1, updated: 2, archived: null),
        summary: null,
      );

      final result = await repository.renameSession(sessionId: "s1", title: "Renamed");

      expect(plugin.lastRenameSessionId, equals("s1"));
      expect(plugin.lastRenameSessionTitle, equals("Renamed"));
      expect(result.pluginId, equals(plugin.id));
      expect(result.title, equals("Renamed"));
      expect(result.hasWorktree, isFalse);
      expect(result.pullRequest, isNull);
    });

    test("findProjectIdForSession returns stored project id without scanning plugin", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p-stored"]);
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s-target",
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
      expect(plugin.projectsResult, isEmpty);
    });

    test("findProjectIdForSession scans projects until it finds the matching session", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      plugin.projectsResult = const [
        PluginProject(id: "project-a", directory: "/repo-a"),
        PluginProject(id: "project-b", directory: "/repo-b"),
      ];
      plugin.sessionsByWorktree = {
        "/repo-a": const [],
        "/repo-b": const [
          PluginSession(
            id: "s-target",
            projectID: "/repo-b",
            directory: "/repo-b",
            parentID: null,
            title: "Session",
            time: null,
            summary: null,
          ),
        ],
      };

      final result = await repository.findProjectIdForSession(sessionId: "s-target");

      expect(result, equals("project-b"));
      expect((await db.projectsDao.getProject(projectId: "project-a"))?.path, "/repo-a");
      expect((await db.projectsDao.getProject(projectId: "project-b"))?.path, "/repo-b");
    });

    test("createSession passes variant directly to plugin", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final cases = <SessionVariant?>[const SessionVariant(id: "low"), const SessionVariant(id: "xhigh"), null];

      for (final variant in cases) {
        await repository.createSession(
          pluginId: plugin.id,
          directory: "/repo",
          parentSessionId: null,
          parts: const [PromptPart.text(text: "Ship it")],
          variant: variant,
          agent: null,
          model: null,
        );

        expect(plugin.lastCreateSessionVariant, equals(variant?.id));
      }
    });

    test("enrichPluginEventSessionJson stamps the active plugin on missing and null attribution", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final sessionJson = const Session(
        id: "event-session",
        pluginId: legacyMissingPluginId,
        projectID: "/repo",
        directory: "/repo",
        parentID: null,
        title: "Event session",
        time: null,
        summary: null,
        pullRequest: null,
        promptDefaults: null,
      ).toJson();

      final missing = await repository.enrichPluginEventSessionJson(sessionJson: sessionJson);
      final explicitNull = await repository.enrichPluginEventSessionJson(
        sessionJson: {...sessionJson, "pluginId": null},
      );

      expect(missing.pluginId, equals(plugin.id));
      expect(explicitNull.pluginId, equals(plugin.id));
    });

    group("moved project (stable id, new live path)", () {
      test("getSessionsForProject hands the plugin the live directory and re-keys sessions to the id", () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        await db.projectsDao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          createdAt: 1,
          updatedAt: 1,
        );
        plugin.sessionsByWorktree = {
          "/moved/a": const [
            PluginSession(
              id: "s-live",
              // The plugin can only echo the directory it was asked about —
              // it has no notion of the bridge's stable identifier.
              projectID: "/moved/a",
              directory: "/moved/a",
              parentID: null,
              title: "Session",
              time: null,
              summary: null,
            ),
          ],
        };

        final repository = SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
          unseenCalculator: const SessionUnseenCalculator(),
        );

        final sessions = await repository.getSessionsForProject(
          projectId: "/projects/a",
          start: null,
          limit: null,
        );

        expect(plugin.lastGetSessionsWorktree, equals("/moved/a"));
        expect(sessions.single.id, equals("s-live"));
        expect(sessions.single.pluginId, equals(plugin.id));
        expect(sessions.single.projectID, equals("/projects/a"));
      });

      test("getCommands resolves the project id to the live directory", () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        await db.projectsDao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          createdAt: 1,
          updatedAt: 1,
        );

        final repository = SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
          unseenCalculator: const SessionUnseenCalculator(),
        );

        await repository.getCommands(projectId: "/projects/a", pluginId: plugin.id);
        expect(plugin.lastGetCommandsProjectId, equals("/moved/a"));

        // Null/blank keeps the plugin's own fallback untouched.
        await repository.getCommands(projectId: "  ", pluginId: plugin.id);
        expect(plugin.lastGetCommandsProjectId, isNull);
      });

      test("getProjectPath returns the live directory, probing the plugin for availability", () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        await db.projectsDao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          createdAt: 1,
          updatedAt: 1,
        );

        final repository = SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
          unseenCalculator: const SessionUnseenCalculator(),
        );

        final path = await repository.getProjectPath(projectId: "/projects/a");

        expect(path, equals("/moved/a"));
        expect(plugin.lastGetProjectDirectory, equals("/moved/a"));
      });

      test("resolveProjectDirectory rejects an unknown project id", () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final repository = SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
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

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final cases = <SessionVariant?>[const SessionVariant(id: "low"), const SessionVariant(id: "xhigh"), null];

      for (final variant in cases) {
        await repository.sendPrompt(
          sessionId: "s1",
          parts: const [PromptPart.text(text: "Prompt")],
          variant: variant,
          agent: null,
          model: null,
        );
        expect(plugin.lastSendPromptVariant, equals(variant?.id));

        await repository.sendCommand(
          sessionId: "s1",
          command: "review",
          arguments: "Prompt",
          variant: variant,
          agent: null,
          model: null,
        );
        expect(plugin.lastSendCommandVariant, equals(variant?.id));
      }
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
      summary: null,
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

    test("getSessionsForProject lists a worktree session under its parent project", () async {
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
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "w1");

      final sessions = await repository.getSessionsForProject(projectId: parent, start: null, limit: null);

      // The in-project session AND the worktree session both list under parent.
      expect(sessions.map((s) => s.id).toSet(), {"s1", "w1"});
      // Enrichment adopts the stored attribution as projectID (the plugin
      // reported the worktree cwd), so live created/updated events for this
      // session are not dropped by the parent project's session list. The
      // directory stays the session's real cwd.
      final worktreeSession = sessions.singleWhere((s) => s.id == "w1");
      expect(worktreeSession.projectID, parent);
      expect(worktreeSession.directory, worktree);
      // The bridge told the plugin where to look: the project being served and
      // the stored session's project + worktree paths — a directory-scoped
      // backend (ACP) can only enumerate directories it is pointed at.
      expect(plugin.receivedKnownDirectories, containsAll(<String>[parent, worktree]));
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
      final repository = SessionRepository(
        unseenCalculator: const SessionUnseenCalculator(),
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
      );
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "a1");

      final result = await repository.findProjectIdForSession(sessionId: "a1");

      expect(result, equals(parent));
    });

    test("findProjectIdForSession resolves a rowless session to its own directory", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const directory = "/tmp/proj/beta";
      // No stored row: the bridge did not create this session, so its own cwd
      // IS its project.
      final plugin = _FakeDerivedPlugin(
        launchDirectory: "/tmp/proj/alpha",
        allSessions: [pluginSession(directory, id: "b1")],
      );
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final result = await repository.findProjectIdForSession(sessionId: "b1");

      expect(result, equals(directory));
    });

    test("findProjectIdForSession hints at opened-but-sessionless folders too", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      // An opened folder with no stored sessions for this plugin: it never
      // appears in the sessions⋈projects join, but a directory-scoped backend
      // can only discover a rowless session there if the hint set includes it.
      const opened = "/tmp/proj/opened-only";
      await db.projectsDao.insertProjectsIfMissing(projectIds: [opened]);
      final plugin = _FakeDerivedPlugin(launchDirectory: "/tmp/proj/alpha", allSessions: const []);
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      await repository.findProjectIdForSession(sessionId: "missing");

      expect(plugin.receivedKnownDirectories, contains(opened));
    });

    test("sendPrompt/sendCommand/getSessionMessages prime a derived plugin with the stored directory", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      final plugin = _FakeDerivedPlugin(launchDirectory: parent, allSessions: const []);
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      // One dedicated-worktree session and one plain in-project session.
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "w1");
      await db.sessionDao.insertSession(
        sessionId: "p1",
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

      // ...and a rowless session primes nothing (there is no stored attribution).
      final primesBefore = plugin.primedDirectories.length;
      await repository.sendPrompt(sessionId: "ghost", parts: const [], variant: null, agent: null, model: null);
      expect(plugin.primedDirectories.length, primesBefore);
    });

    test("getProjectActivitySummaries folds a worktree session under its stored parent project", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      final plugin = _FakeDerivedPlugin(launchDirectory: parent, allSessions: const []);
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
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
      expect(byId.keys, containsAll(<String>[parent, "/tmp/proj/beta"]));
      expect(byId.keys, isNot(contains(worktree)));
      expect(byId[parent]!.activeSessions.single.id, "w1");
      expect(byId[parent]!.activeSessions.single.mainAgentRunning, isTrue);
      // A rowless session keeps the plugin's own grouping.
      expect(byId["/tmp/proj/beta"]!.activeSessions.single.id, "b1");
      expect(byId["/tmp/proj/beta"]!.activeSessions.single.awaitingInput, isTrue);
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
            summary: null,
          ),
        ],
      );
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);
      await db.sessionDao.insertSession(
        sessionId: "s1",
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
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
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

    test("getChildSessions filters tombstoned derived children", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final plugin =
          _FakeDerivedPlugin(
              launchDirectory: "/repo",
              allSessions: const [],
            )
            ..childSessions = [
              pluginSession("/repo", id: "live-child"),
              pluginSession("/repo", id: "gone-child"),
            ];
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone-child",
        pluginId: plugin.id,
        deletedAt: 1,
      );

      final children = await repository.getChildSessions(sessionId: "live-parent");

      expect(children.map((session) => session.id), ["live-child"]);
      expect(children.single.pluginId, equals(plugin.id));
    });

    test("deleteSession survives rowless project discovery failure", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final plugin = _FakeDerivedPlugin(
        launchDirectory: "/repo",
        allSessions: const [],
      )..listAllSessionsError = StateError("enumeration failed");
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final deleted = await repository.deleteSession(sessionId: "rowless");

      expect(deleted.projectID, isEmpty);
      expect(plugin.deleteCalls, 1);
      expect(
        await db.sessionDao.isSessionTombstoned(backendSessionId: "rowless", pluginId: plugin.id),
        isTrue,
      );
    });

    test("deleteSession tombstones the stored backend identity", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final plugin = _FakeDerivedPlugin(launchDirectory: "/repo", allSessions: const []);
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await repository.insertStoredSession(
        sessionId: "sesori-id",
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
      await (db.update(db.sessionTable)..where((table) => table.sessionId.equals("sesori-id"))).write(
        const SessionTableCompanion(backendSessionId: Value("backend-id")),
      );

      await repository.deleteSession(sessionId: "sesori-id");

      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "backend-id", pluginId: plugin.id), isTrue);
      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "sesori-id", pluginId: plugin.id), isFalse);
    });

    test("tombstoned sessions are filtered from enumeration and resolution", () async {
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
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "deleted-s",
        pluginId: "codex",
        deletedAt: 1,
      );

      final sessions = await repository.getSessionsForProject(projectId: parent, start: null, limit: null);
      expect(sessions.map((s) => s.id), ["kept-s"]);

      expect(await repository.findProjectIdForSession(sessionId: "deleted-s"), isNull);
      expect(await repository.findProjectIdForSession(sessionId: "kept-s"), parent);
    });

    test("sessionListIsAuthoritative is false for a derived plugin and true for a native one", () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final pullRequestRepository = PullRequestRepository(
        pullRequestDao: db.pullRequestDao,
        projectsDao: db.projectsDao,
      );

      final derived = SessionRepository(
        plugin: _FakeDerivedPlugin(launchDirectory: "/tmp/proj/alpha", allSessions: const []),
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: pullRequestRepository,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final native = SessionRepository(
        plugin: _FakeBridgePlugin(),
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: pullRequestRepository,
        unseenCalculator: const SessionUnseenCalculator(),
      );

      // A derived enumeration is eventually-complete (rollout flush window),
      // so it must never be used to reconcile stored rows away.
      expect(derived.sessionListIsAuthoritative, isFalse);
      expect(native.sessionListIsAuthoritative, isTrue);
    });

    test("getSessionsForProject scoped to the worktree path returns nothing — it belongs to its parent", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      final plugin = _FakeDerivedPlugin(
        launchDirectory: parent,
        allSessions: [pluginSession(worktree, id: "w1")],
      );
      final repository = SessionRepository(
        unseenCalculator: const SessionUnseenCalculator(),
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
      );
      await recordWorktreeSession(db, parent: parent, worktree: worktree, sessionId: "w1");

      final underWorktree = await repository.getSessionsForProject(projectId: worktree, start: null, limit: null);

      expect(underWorktree, isEmpty);
    });
  });
}

class _FakeBridgePlugin implements NativeProjectsPluginApi {
  List<PluginProject> projectsResult = const [];
  List<PluginSession> sessionsResult = const [];
  Map<String, List<PluginSession>> sessionsByWorktree = const {};
  PluginSession createSessionResult = const PluginSession(
    id: "created-session",
    projectID: "/repo",
    directory: "/repo",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );
  PluginSession? renameSessionResult;
  String? lastRenameSessionId;
  String? lastRenameSessionTitle;
  String? lastCreateSessionVariant;
  int createSessionCalls = 0;
  String? lastSendPromptVariant;
  String? lastSendCommandVariant;
  String? lastGetSessionsWorktree;
  String? lastGetCommandsProjectId;
  String? lastGetProjectDirectory;

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<PluginProject>> getProjects() async => projectsResult;

  @override
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit}) async {
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
    return PluginProject(id: projectId, directory: projectId);
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
    lastSendCommandVariant = variant?.id;
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  Object? listAllSessionsError;
  int deleteCalls = 0;

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
      summary: null,
    );
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => childSessions;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => activitySummaries;

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

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
