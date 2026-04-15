import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/routing/rename_session_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("RenameSessionHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late SessionRepository sessionRepository;
    late RenameSessionHandler handler;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      sessionRepository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
      );
      handler = RenameSessionHandler(plugin: plugin, sessionRepository: sessionRepository);
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle PATCH /session/title", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/title")), isTrue);
    });

    test("does not handle GET /session/title", () {
      expect(handler.canHandle(makeRequest("GET", "/session/title")), isFalse);
    });

    test("does not handle PATCH /session/:id/title", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/s1/title")), isFalse);
    });

    test("does not handle PATCH /session/:id", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/s1")), isFalse);
    });

    test("extracts sessionId and title from typed body", () async {
      plugin.renameSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: "New Title",
        time: null,
        summary: null,
      );

      await handler.handle(
        makeRequest("PATCH", "/session/title"),
        body: const RenameSessionRequest(sessionId: "s1", title: "New Title"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastRenameSessionId, equals("s1"));
      expect(plugin.lastRenameSessionTitle, equals("New Title"));
    });

    test("returns mapped Session", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/tmp",
        branchName: "feature/rename",
        baseBranch: null,
        baseCommit: null,
      );
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "p1",
          branchName: "feature/rename",
          prNumber: 13,
          url: "https://github.com/org/repo/pull/13",
          title: "Rename PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.unknown,
          reviewDecision: PrReviewDecision.unknown,
          checkStatus: PrCheckStatus.unknown,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

      plugin.renameSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: "parent-1",
        title: "Renamed Session",
        time: PluginSessionTime(created: 10, updated: 20, archived: 30),
        summary: PluginSessionSummary(additions: 4, deletions: 1, files: 2),
      );

      final result = await handler.handle(
        makeRequest("PATCH", "/session/title"),
        body: const RenameSessionRequest(sessionId: "s1", title: "Renamed Session"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      expect(result.projectID, equals("p1"));
      expect(result.directory, equals("/tmp"));
      expect(result.parentID, equals("parent-1"));
      expect(result.title, equals("Renamed Session"));
      expect(result.time?.created, equals(10));
      expect(result.time?.updated, equals(20));
      expect(result.time?.archived, isNull);
      expect(result.summary?.additions, equals(4));
      expect(result.summary?.deletions, equals(1));
      expect(result.summary?.files, equals(2));
      expect(result.pullRequest?.number, equals(13));
      expect(result.pullRequest?.title, equals("Rename PR"));
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("PATCH", "/session/title"),
          body: const RenameSessionRequest(sessionId: "", title: "New Title"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
