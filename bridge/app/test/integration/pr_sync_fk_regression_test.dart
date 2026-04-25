/// End-to-end regression test for the PR sync FK constraint bug.
///
/// Background: `PrSyncService` calls `PullRequestRepository.upsertFromGhPr`
/// for projects that exist in plugin memory but NOT in `projects_table`.
/// With `PRAGMA foreign_keys = ON`, this caused `FOREIGN KEY constraint failed`
/// because `pull_requests_table.projectId` references `projects_table.project_id`.
///
/// This test proves that the three forward-prevention paths (T5, T7, T9) fix
/// the bug WITHOUT requiring the v5 schema migration. The v5 migration adds a
/// belt-and-suspenders FK from `session_table.projectId` → `projects_table`,
/// but the core PR sync bug is already fixed by the time T10 runs.
///
/// Scenario A — Primary path (GetProjects before PR sync):
///   ProjectRepository.getProjects() persists projects; subsequent
///   PullRequestRepository.upsertFromGhPr succeeds without FK exception.
///
/// Scenario B — Defensive path (skip GetProjects, go straight to upsertFromGhPr):
///   PullRequestRepository.upsertFromGhPr calls insertProjectIfMissing
///   defensively (T9), so even if GetProjects never ran, the PR upsert
///   creates the project row and succeeds.
///
/// Scenario C — GetSessions path (T7 flow):
///   SessionPersistenceService.ensureProject + persistSessionsForProject
///   create the project row and session rows without FK exceptions.
library;

import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";

void main() {
  group("PR sync FK regression — forward-prevention paths (pre-v5 schema)", () {
    // -------------------------------------------------------------------------
    // Scenario A — Primary path: GetProjects before PR sync
    // -------------------------------------------------------------------------
    test(
      "Scenario A: ProjectRepository.getProjects persists project; "
      "subsequent upsertFromGhPr succeeds without FK exception",
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final plugin = _FakeBridgePlugin(
          projects: const [
            PluginProject(
              id: "proj-X",
              name: "Project X",
              time: PluginProjectTime(created: 0, updated: 100),
            ),
          ],
        );

        final projectRepo = ProjectRepository(
          plugin: plugin,
          projectsDao: db.projectsDao,
        );
        final prRepo = PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        );

        // Primary fix (T5): getProjects persists the project row.
        await projectRepo.getProjects();

        final projectRows = await db.select(db.projectsTable).get();
        expect(
          projectRows.map((r) => r.projectId).toList(),
          contains("proj-X"),
          reason: "getProjects must persist the project row",
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
          reason: "no FK exception when project row was pre-seeded by getProjects",
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

        // Defensive fix (T9): upsertFromGhPr calls insertProjectIfMissing.
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
    // Scenario C — GetSessions path: T7 flow via SessionPersistenceService
    // -------------------------------------------------------------------------
    test(
      "Scenario C: SessionPersistenceService.ensureProject + persistSessionsForProject "
      "create project and session rows without FK exception",
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final service = SessionPersistenceService(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          db: db,
        );

        // Verify projects_table is empty before the call.
        final emptyRows = await db.select(db.projectsTable).get();
        expect(emptyRows, isEmpty, reason: "projects_table must be empty before the call");

        final sessions = [
          _session(id: "sess-1", projectId: "sess-proj", createdAt: 1000),
          _session(id: "sess-2", projectId: "sess-proj", createdAt: 2000),
          _session(id: "sess-3", projectId: "sess-proj", createdAt: 3000),
        ];

        // T7 fix: ensureProject creates the project row.
        // Direct await — if an exception were thrown, the test would fail here.
        await service.ensureProject(projectId: "sess-proj");

        // T7 fix: persistSessionsForProject inserts all 3 session rows.
        await service.persistSessionsForProject(
          projectId: "sess-proj",
          sessions: sessions,
        );

        // projects_table has "sess-proj".
        final projectRows = await db.select(db.projectsTable).get();
        expect(
          projectRows.map((r) => r.projectId).toList(),
          contains("sess-proj"),
          reason: "ensureProject must create the project row",
        );

        // session_table has 3 placeholder rows.
        final sessionRows = await db.select(db.sessionTable).get();
        expect(
          sessionRows,
          hasLength(3),
          reason: "persistSessionsForProject must insert 3 session rows",
        );
        expect(
          sessionRows.map((r) => r.sessionId).toSet(),
          equals({"sess-1", "sess-2", "sess-3"}),
        );
        for (final row in sessionRows) {
          expect(row.projectId, equals("sess-proj"));
          expect(row.isDedicated, isFalse, reason: "placeholder sessions are non-dedicated");
        }
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

/// Constructs a minimal [Session] for use in session persistence tests.
Session _session({
  required String id,
  required String projectId,
  required int createdAt,
}) => Session(
  id: id,
  projectID: projectId,
  directory: "/tmp/$projectId",
  parentID: null,
  title: null,
  time: SessionTime(created: createdAt, updated: createdAt, archived: null),
  summary: null,
  pullRequest: null,
);

/// Minimal [BridgePlugin] fake that only implements [getProjects].
/// Every other member throws [UnimplementedError] so accidental use is loud.
class _FakeBridgePlugin implements BridgePlugin {
  final List<PluginProject> _projects;

  _FakeBridgePlugin({required List<PluginProject> projects}) : _projects = projects;

  @override
  Future<List<PluginProject>> getProjects() async => _projects;

  @override
  String get id => throw UnimplementedError();

  @override
  Stream<BridgeSseEvent> get events => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) => throw UnimplementedError();

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
  Future<List<PluginAgent>> getAgents() => throw UnimplementedError();

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
  Future<void> rejectQuestion(String questionId) => throw UnimplementedError();

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
  Future<PluginProvidersResult> getProviders({required bool connectedOnly, String? directory}) =>
      throw UnimplementedError();

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => throw UnimplementedError();

  @override
  Future<void> dispose() => throw UnimplementedError();
}
