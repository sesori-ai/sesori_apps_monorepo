/// End-to-end regression test for the PR sync FK constraint bug.
///
/// Background: `PrSyncService` calls `PullRequestRepository.replaceScopedPullRequests`
/// for projects that exist in plugin memory but NOT in `projects_table`.
/// With `PRAGMA foreign_keys = ON`, this caused `FOREIGN KEY constraint failed`
/// because `pull_requests_table.projectId` references `projects_table.project_id`.
///
/// This test proves that catalog reads, fail-closed PR upsert, and imported
/// session bindings all preserve the relevant foreign-key invariants.
///
/// Scenario A — Primary path (catalog project before PR sync):
///   ProjectRepository.getProjects() reads an imported project; subsequent
///   PullRequestRepository.replaceScopedPullRequests succeeds without FK exception.
///
/// Scenario B — Missing catalog path:
///   PullRequestRepository.replaceScopedPullRequests returns a scope-changed
///   outcome instead of fabricating a project row whose path would be inferred
///   from its id.
///
/// Scenario C — GetSessions path:
///   SessionRepository.getSessionsForProject reads imported bindings without FK
///   exceptions.
library;

import "package:sesori_bridge/src/api/gh_pull_request.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_selection.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_target.dart";
import "package:sesori_bridge/src/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/fake_filesystem_api.dart";
import "../helpers/fake_git_cli_api.dart";
import "../helpers/test_database.dart";

const _githubLogin = "octocat";
const _githubRepositoryIdentity = "sesori-ai/sesori_apps_monorepo";
final _verifiedGithubLogin = VerifiedGithubLogin.tryParse(rawLogin: _githubLogin)!;

void main() {
  group("PR sync FK regression — forward-prevention paths (pre-v5 schema)", () {
    // -------------------------------------------------------------------------
    // Scenario A — Primary path: catalog project before PR sync
    // -------------------------------------------------------------------------
    test(
      "Scenario A: ProjectRepository.getProjects reads a catalog project; "
      "subsequent scoped replacement succeeds without FK exception",
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final projectRepo = singlePluginProjectRepository(
          gitCliApi: FakeGitCliApi(),
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        );
        final prRepo = PullRequestRepository(
          database: db,
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
        );

        await db.projectsDao.recordOpenedProject(
          projectId: "proj-X",
          path: "proj-X",
          displayName: null,
          createdAt: 0,
          updatedAt: 100,
        );
        await projectRepo.getProjects();
        await db.sessionDao.insertSession(
          sessionId: "session-X",
          backendSessionId: "session-X",
          projectId: "proj-X",
          isDedicated: false,
          createdAt: 1,
          worktreePath: null,
          branchName: "created-branch",
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
          pluginId: "opencode",
          preservePullRequestScope: false,
        );
        await db.sessionDao.updatePullRequestScopes(
          updates: const [
            (
              sessionId: "session-X",
              currentBranchName: "feature-branch",
              currentGithubRepositoryIdentity: _githubRepositoryIdentity,
            ),
          ],
        );
        await db.projectsDao.setPrCacheGithubLogin(
          projectId: "proj-X",
          githubLogin: _githubLogin,
        );

        final projectRows = await db.select(db.projectsTable).get();
        expect(
          projectRows.map((r) => r.projectId).toList(),
          contains("proj-X"),
          reason: "the imported project row must remain available",
        );

        // Now scoped replacement must succeed — project row already exists.
        // Direct await (not expectLater) to ensure the future is fully resolved
        // before querying the DB.
        final outcome = await prRepo.replaceScopedPullRequests(
          projectId: "proj-X",
          verifiedGithubLogin: _verifiedGithubLogin,
          capturedRootDirectoriesBySessionId: const {"session-X": "proj-X"},
          targetSelections: [_selectedPullRequest()],
          lastCheckedAt: 2,
        );
        expect(outcome, isA<PullRequestReplacementApplied>());

        final prRows = await db.pullRequestDao.getPrsByProjectId(projectId: "proj-X");
        expect(
          prRows,
          hasLength(1),
          reason: "no FK exception when the catalog already contains the project",
        );
        expect(prRows.first.prNumber, equals(42));
        expect(prRows.first.projectId, equals("proj-X"));
      },
    );

    // -------------------------------------------------------------------------
    // Scenario B — Missing catalog path fails closed
    // -------------------------------------------------------------------------
    test(
      "Scenario B: scoped replacement does not fabricate a missing catalog project",
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final prRepo = PullRequestRepository(
          database: db,
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
        );

        // Verify projects_table is empty — GetProjects never ran.
        final emptyRows = await db.select(db.projectsTable).get();
        expect(emptyRows, isEmpty, reason: "projects_table must be empty before the call");

        final outcome = await prRepo.replaceScopedPullRequests(
          projectId: "ghost",
          verifiedGithubLogin: _verifiedGithubLogin,
          capturedRootDirectoriesBySessionId: const {},
          targetSelections: [_selectedPullRequest()],
          lastCheckedAt: 2,
        );
        expect(outcome, isA<PullRequestReplacementScopeChanged>());

        final projectRows = await db.select(db.projectsTable).get();
        expect(projectRows, isEmpty);

        final prRows = await db.pullRequestDao.getPrsByProjectId(projectId: "ghost");
        expect(prRows, isEmpty);
      },
    );

    // -------------------------------------------------------------------------
    // Scenario C — GetSessions path via SessionRepository
    // -------------------------------------------------------------------------
    test(
      "Scenario C: SessionRepository.getSessionsForProject reads bindings without FK exception",
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final plugin = _FakeBridgePlugin(
          projects: const [],
          sessions: [
            _session(id: "sess-1", projectId: "sess-proj", createdAt: 1000),
            _session(id: "sess-2", projectId: "sess-proj", createdAt: 2000),
            _session(id: "sess-3", projectId: "sess-proj", createdAt: 3000),
          ],
        );
        final repository = singlePluginSessionRepository(
          plugin: plugin,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        );

        await db.projectsDao.recordOpenedProject(
          projectId: "sess-proj",
          path: "/tmp/sess-proj",
          displayName: null,
          createdAt: 1,
          updatedAt: 1,
        );
        await db.sessionDao.insertSessionsIfMissing(
          pluginId: plugin.id,
          sessions: [
            for (var index = 1; index <= 3; index++)
              (
                sessionId: "stable-$index",
                backendSessionId: "sess-$index",
                projectId: "sess-proj",
                directory: "/tmp/sess-proj",
                createdAt: index * 1000,
                archivedAt: null,
              ),
          ],
        );
        final sessions = await repository.getSessionsForProject(
          projectId: "sess-proj",
          start: null,
          limit: null,
          verifiedGithubLogin: null,
        );

        // projects_table has "sess-proj".
        final projectRows = await db.select(db.projectsTable).get();
        expect(
          projectRows.map((r) => r.projectId).toList(),
          contains("sess-proj"),
          reason: "the discovered project remains available for binding publication",
        );

        // The imported stable/backend bindings remain unchanged by the read.
        final sessionRows = await db.select(db.sessionTable).get();
        expect(
          sessionRows,
          hasLength(3),
          reason: "getSessionsForProject must return 3 imported session bindings",
        );
        expect(
          sessionRows.map((r) => r.backendSessionId).toSet(),
          equals({"sess-1", "sess-2", "sess-3"}),
        );
        for (final row in sessionRows) {
          expect(row.sessionId, startsWith("stable-"));
          expect(row.sessionId, isNot(row.backendSessionId));
          expect(row.pluginId, equals(plugin.id));
          expect(row.projectId, equals("sess-proj"));
          expect(row.directory, equals("/tmp/sess-proj"));
        }
        expect(
          sessions.map((session) => session.id).toSet(),
          equals(sessionRows.map((row) => row.sessionId).toSet()),
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Constructs a target-bound selected PR for persistence tests.
PullRequestTargetSelected _selectedPullRequest() => PullRequestTargetSelected(
  target: (
    githubRepositoryIdentity: _githubRepositoryIdentity,
    branchName: "feature-branch",
  ),
  pullRequest: GhPullRequest(
    number: 42,
    url: "https://github.com/org/repo/pull/42",
    title: "Test PR",
    createdAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
    state: PrState.open,
    headRefName: "feature-branch",
    mergeable: PrMergeableStatus.mergeable,
    reviewDecision: PrReviewDecision.reviewRequired,
    statusCheckRollup: PrCheckStatus.success,
  ),
);

/// Constructs a minimal [PluginSession] for use in session publication tests.
PluginSession _session({
  required String id,
  required String projectId,
  required int createdAt,
}) => PluginSession(
  id: id,
  projectID: projectId,
  directory: "/tmp/$projectId",
  parentID: null,
  title: null,
  time: PluginSessionTime(created: createdAt, updated: createdAt, archived: null),
);

/// Minimal [BridgePluginApi] fake that only implements identity and [getProjects].
/// Every other member throws [UnimplementedError] so accidental use is loud.
class _FakeBridgePlugin({required final List<PluginProject> _projects, required final List<PluginSession> _sessions})
    implements NativeProjectsPluginApi {
  @override
  Future<List<PluginProject>> getProjects() async => _projects;

  @override
  String get id => "opencode";

  @override
  Stream<BridgeSseEvent> get events => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getSessions({required String projectId, required int? start, required int? limit}) async => _sessions;

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => const [];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => const [];

  @override
  Future<void> sendCommand({
    required String promptId,
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
