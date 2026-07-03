import "dart:async";

import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
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

    test("enrichSession merges stored archive and selected PR metadata", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
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

    test("renameSession delegates to plugin and returns enriched shared session", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
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
      expect(result.title, equals("Renamed"));
      expect(result.hasWorktree, isTrue);
      expect(result.pullRequest?.number, equals(12));
    });

    test("findProjectIdForSession returns stored project id without scanning plugin", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
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
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      plugin.projectsResult = const [
        PluginProject(id: "/repo-a"),
        PluginProject(id: "/repo-b"),
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

      expect(result, equals("/repo-b"));
    });

    test("createSession passes variant directly to plugin", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final cases = <SessionVariant?>[const SessionVariant(id: "low"), const SessionVariant(id: "xhigh"), null];

      for (final variant in cases) {
        await repository.createSession(
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

    test("sendPrompt and sendCommand pass variant directly to plugin", () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
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
        allSessions: [pluginSession(parent, id: "s1"), pluginSession(worktree, id: "w1")],
      );
      final repository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
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
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
        unseenCalculator: const SessionUnseenCalculator(),
      );

      final result = await repository.findProjectIdForSession(sessionId: "b1");

      expect(result, equals(directory));
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
  String? lastSendPromptVariant;
  String? lastSendCommandVariant;

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  Future<List<PluginProject>> getProjects() async => projectsResult;

  @override
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit}) async {
    return sessionsByWorktree[worktree] ?? sessionsResult;
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

/// A derive-style plugin (Codex/ACP shaped): reports every session through
/// [BridgeDerivedProjectsPluginApi.listAllSessions]. `id` is "codex" so the
/// repository's stored-attribution lookup
/// (`getSessionProjectPaths(pluginId: ...)`) matches the seeded session rows.
class _FakeDerivedPlugin implements BridgeDerivedProjectsPluginApi {
  _FakeDerivedPlugin({required this.launchDirectory, required this.allSessions});

  @override
  final String launchDirectory;

  List<PluginSession> allSessions;

  @override
  String get id => "codex";

  @override
  Future<List<PluginSession>> listAllSessions() async => allSessions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
