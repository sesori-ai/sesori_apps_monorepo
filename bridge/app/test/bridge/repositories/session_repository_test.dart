import "dart:async";

import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
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
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/one",
        baseBranch: null,
        baseCommit: null,
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
          branchName: null,
          parentID: null,
          title: "session",
          time: SessionTime(created: 1, updated: 2, archived: null),
          summary: null,
          pullRequest: null,
        ),
      );

      expect(result.time?.created, equals(1));
      expect(result.time?.updated, equals(2));
      expect(result.time?.archived, isNull);
      expect(result.hasWorktree, isTrue);
      expect(result.pullRequest?.number, equals(11));
      expect(result.pullRequest?.state, equals(PrState.open));
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
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "p1",
        isDedicated: false,
        createdAt: 10,
        worktreePath: null,
        branchName: "feature/one",
        baseBranch: null,
        baseCommit: null,
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
            branchName: null,
            parentID: null,
            title: "stored",
            time: null,
            summary: null,
            pullRequest: null,
          ),
          Session(
            id: "s2",
            projectID: "p1",
            directory: "/tmp/project",
            branchName: null,
            parentID: null,
            title: "unstored",
            time: SessionTime(created: 3, updated: 4, archived: null),
            summary: null,
            pullRequest: null,
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
      );

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 10,
        worktreePath: "/tmp/worktree",
        branchName: "feature/rename",
        baseBranch: null,
        baseCommit: null,
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
      );

      plugin.projectsResult = const [
        PluginProject(id: "/repo-a"),
        PluginProject(id: "/repo-b"),
      ];
      plugin.sessionsResult = const [
        PluginSession(
          id: "s-target",
          projectID: "/repo-b",
          directory: "/repo-b",
          parentID: null,
          title: "Session",
          time: null,
          summary: null,
        ),
      ];

      final result = await repository.findProjectIdForSession(sessionId: "s-target");

      expect(result, equals("/repo-a"));
    });
  });
}

class _FakeBridgePlugin implements BridgePlugin {
  List<PluginProject> projectsResult = const [];
  List<PluginSession> sessionsResult = const [];
  PluginSession? renameSessionResult;
  String? lastRenameSessionId;
  String? lastRenameSessionTitle;

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  Future<List<PluginProject>> getProjects() async => projectsResult;

  @override
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit}) async => sessionsResult;

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    lastRenameSessionId = sessionId;
    lastRenameSessionTitle = title;
    return renameSessionResult!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
