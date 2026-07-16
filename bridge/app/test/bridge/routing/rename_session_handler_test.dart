import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/rename_session_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("RenameSessionHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late SessionRepository sessionRepository;
    late RenameSessionHandler handler;

    setUp(() async {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      sessionRepository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        gitCliApi: FakeGitCliApi(),
        unseenCalculator: const SessionUnseenCalculator(),
      );
      handler = RenameSessionHandler(
        sessionMutationDispatcher: SessionMutationDispatcher(sessionRepository: sessionRepository),
      );
      await sessionRepository.insertStoredSession(
        sessionId: "s1",
        backendSessionId: "backend-s1",
        pluginId: "fake",
        projectId: "p1",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
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
      );

      await handler.handle(
        makeRequest("PATCH", "/session/title"),
        body: const RenameSessionRequest(sessionId: "s1", title: "New Title"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastRenameSessionId, equals("backend-s1"));
      expect(plugin.lastRenameSessionTitle, equals("New Title"));
    });

    test("returns mapped Session", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.sessionDao.insertSession(
        pluginId: "fake",
        sessionId: "s1",
        backendSessionId: "backend-s1",
        projectId: "p1",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/tmp",
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
      expect(result.pullRequest?.number, equals(13));
      expect(result.pullRequest?.title, equals("Rename PR"));
      expect(plugin.lastRenameSessionId, equals("backend-s1"));
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

    test("missing binding returns 404 before plugin I/O", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "PATCH",
          "/session/title",
          body: jsonEncode(const RenameSessionRequest(sessionId: "missing", title: "New Title").toJson()),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 404);
      expect(plugin.lastRenameSessionId, isNull);
    });

    test("stored plugin mismatch returns 503 before plugin I/O", () async {
      await sessionRepository.insertStoredSession(
        sessionId: "stale-plugin-session",
        backendSessionId: "backend-stale-plugin-session",
        pluginId: "stopped-plugin",
        projectId: "p1",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );

      final response = await handler.handleInternal(
        makeRequest(
          "PATCH",
          "/session/title",
          body: jsonEncode(
            const RenameSessionRequest(sessionId: "stale-plugin-session", title: "New Title").toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 503);
      expect(plugin.lastRenameSessionId, isNull);
    });
  });
}
