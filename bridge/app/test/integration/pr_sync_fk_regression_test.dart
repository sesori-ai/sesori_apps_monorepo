/// End-to-end regression test for the PR sync FK constraint bug.
///
/// Background: `PrSyncService` calls `PullRequestRepository.upsertFromGhPr`
/// for projects that exist in plugin memory but NOT in `projects_table`.
/// With `PRAGMA foreign_keys = ON`, this caused `FOREIGN KEY constraint failed`
/// because `pull_requests_table.projectId` references `projects_table.project_id`.
///
/// This test proves that catalog reads, defensive PR upsert, and imported
/// session bindings all preserve the relevant foreign-key invariants.
///
/// Scenario A — Primary path (catalog project before PR sync):
///   ProjectRepository.getProjects() reads an imported project; subsequent
///   PullRequestRepository.upsertFromGhPr succeeds without FK exception.
///
/// Scenario B — Defensive path (skip GetProjects, go straight to upsertFromGhPr):
///   PullRequestRepository.upsertFromGhPr calls insertProjectIfMissing
///   defensively (T9), so even if GetProjects never ran, the PR upsert
///   creates the project row and succeeds.
///
/// Scenario C — GetSessions path:
///   SessionRepository.getSessionsForProject reads imported bindings without FK
///   exceptions.
library;

import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/fake_filesystem_api.dart";
import "../helpers/fake_git_cli_api.dart";
import "../helpers/test_database.dart";

void main() {
  group("PR sync FK regression — forward-prevention paths (pre-v5 schema)", () {
    // -------------------------------------------------------------------------
    // Scenario A — Primary path: catalog project before PR sync
    // -------------------------------------------------------------------------
    test(
      "Scenario A: ProjectRepository.getProjects reads a catalog project; "
      "subsequent upsertFromGhPr succeeds without FK exception",
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final plugin = _FakeBridgePlugin(
          projects: const [
            PluginProject(
              id: "proj-X",
              directory: "proj-X",
              name: "Project X",
              activity: PluginProjectActivity(createdAt: 0, updatedAt: 100),
            ),
          ],
          sessions: const [],
        );

        final projectRepo = singlePluginProjectRepository(
          gitCliApi: FakeGitCliApi(),
          plugin: plugin,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        );
        final prRepo = PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        );

        await db.projectsDao.recordOpenedProject(
          projectId: "proj-X",
          path: "proj-X",
          displayName: null,
          createdAt: 0,
          updatedAt: 100,
        );
        await projectRepo.getProjects();

        final projectRows = await db.select(db.projectsTable).get();
        expect(
          projectRows.map((r) => r.projectId).toList(),
          contains("proj-X"),
          reason: "the imported project row must remain available",
        );

        // Now upsertFromGhPr must succeed — project row already exists.
        // Direct await (not expectLater) to ensure the future is fully resolved
        // before querying the DB.
        await prRepo.upsertFromGhPr(
          projectId: "proj-X",
          pr: _fakePr(),
          createdAt: 1,
          lastCheckedAt: 2,
        );

        final prRows = await db.pullRequestDao.getActivePrsByProjectId(projectId: "proj-X");
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
    // Scenario B — Defensive path: skip GetProjects, go straight to upsertFromGhPr
    // -------------------------------------------------------------------------
    test(
      "Scenario B: upsertFromGhPr creates project row defensively (T9) "
      "even when GetProjects never ran",
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final prRepo = PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        );

        // Verify projects_table is empty — GetProjects never ran.
        final emptyRows = await db.select(db.projectsTable).get();
        expect(emptyRows, isEmpty, reason: "projects_table must be empty before the call");

        // The defensive upsert path calls insertProjectIfMissing.
        // Direct await — if FK exception were thrown, the test would fail here.
        await prRepo.upsertFromGhPr(
          projectId: "ghost",
          pr: _fakePr(),
          createdAt: 1,
          lastCheckedAt: 2,
        );

        // projects_table now has "ghost" — created by insertProjectIfMissing.
        final projectRows = await db.select(db.projectsTable).get();
        expect(
          projectRows.map((r) => r.projectId).toList(),
          contains("ghost"),
          reason: "upsertFromGhPr must insert the project row if missing",
        );

        // pull_requests_table has the PR row.
        final prRows = await db.pullRequestDao.getActivePrsByProjectId(projectId: "ghost");
        expect(prRows, hasLength(1));
        expect(prRows.first.prNumber, equals(42));
        expect(prRows.first.projectId, equals("ghost"));
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

/// Constructs a minimal [GhPullRequest] for use in PR upsert tests.
GhPullRequest _fakePr() => const GhPullRequest(
  number: 42,
  url: "https://github.com/org/repo/pull/42",
  title: "Test PR",
  state: PrState.open,
  headRefName: "feature-branch",
  mergeable: PrMergeableStatus.mergeable,
  reviewDecision: PrReviewDecision.reviewRequired,
  statusCheckRollup: PrCheckStatus.success,
);

/// Constructs a minimal [PluginSession] for use in session publication tests.
PluginSession _session({
  required String id,
  required String projectId,
  required int createdAt,
}) => PluginSession(
  branchName: null,
  id: id,
  projectID: projectId,
  directory: "/tmp/$projectId",
  parentID: null,
  title: null,
  time: PluginSessionTime(created: createdAt, updated: createdAt, archived: null),
);

/// Minimal [BridgePluginApi] fake that only implements identity and [getProjects].
/// Every other member throws [UnimplementedError] so accidental use is loud.
class _FakeBridgePlugin implements NativeProjectsPluginApi {
  final List<PluginProject> _projects;
  final List<PluginSession> _sessions;

  _FakeBridgePlugin({required List<PluginProject> projects, required List<PluginSession> sessions})
    : _projects = projects,
      _sessions = sessions;

  @override
  Future<List<PluginProject>> getProjects() async => _projects;

  @override
  String get id => "opencode";

  @override
  Stream<BridgeSseEvent> get events => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) async => _sessions;

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) => throw UnimplementedError();

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) => throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId) => throw UnimplementedError();

  @override
  Future<void> archiveSession({required String sessionId}) => throw UnimplementedError();

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) => throw UnimplementedError();

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() => throw UnimplementedError();

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) => throw UnimplementedError();

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => <PluginCommand>[];

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

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
  Future<void> abortSession({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) => throw UnimplementedError();

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) => throw UnimplementedError();

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) => throw UnimplementedError();

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) => throw UnimplementedError();

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) => throw UnimplementedError();

  @override
  Future<PluginProject> getProject(String projectId) => throw UnimplementedError();

  @override
  Future<bool> healthCheck() => throw UnimplementedError();

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) => throw UnimplementedError();

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => throw UnimplementedError();

  @override
  Future<void> dispose() => throw UnimplementedError();
}
