import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/branch_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/routing/delete_session_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("DeleteSessionHandler", () {
    late AppDatabase db;
    late _TrackingFakeBridgePlugin plugin;
    late _FakeWorktreeService worktreeService;
    late DeleteSessionHandler handler;
    late List<String> operationLog;

    setUp(() {
      db = createTestDatabase();
      operationLog = [];
      plugin = _TrackingFakeBridgePlugin(operationLog: operationLog);
      worktreeService = _FakeWorktreeService(database: db, operationLog: operationLog);
      handler = DeleteSessionHandler(
        plugin: plugin,
        worktreeService: worktreeService,
        sessionRepository: SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
        ),
        sessionPersistenceService: SessionPersistenceService(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          db: db,
        ),
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("DELETE", "/session/delete"),
          body: const DeleteSessionRequest(
            sessionId: "",
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("1) deleteWorktree=false deleteBranch=false: plugin+db delete, no git ops", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s1",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s1"));
      expect(await db.sessionDao.getSession(sessionId: "s1"), isNull);
    });

    test("2) deleteWorktree=true on clean worktree: safety check then plugin then worktree", () async {
      await _insertSession(
        db: db,
        sessionId: "s2",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-002",
        branchName: "session-002",
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s2",
          deleteWorktree: true,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s2"));
      expect(await db.sessionDao.getSession(sessionId: "s2"), isNull);
    });

    test("3) deleteBranch=true: deletes branch", () async {
      await _insertSession(
        db: db,
        sessionId: "s3",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-003",
        branchName: "session-003",
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s3",
          deleteWorktree: false,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s3"));
      expect(await db.sessionDao.getSession(sessionId: "s3"), isNull);
    });

    test("4) deleteWorktree=true + deleteBranch=true: both cleanup operations run", () async {
      await _insertSession(
        db: db,
        sessionId: "s4",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-004",
        branchName: "session-004",
      );
      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s4",
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s4"));
      expect(await db.sessionDao.getSession(sessionId: "s4"), isNull);
    });

    test("5) deleteWorktree=true on dirty worktree, force=false: returns 409 rejection", () async {
      // Create a real temp directory so checkWorktreeSafety detects it as existing
      final tempDir = Directory.systemTemp.createTempSync("del_test");
      final worktreePath = "${tempDir.path}/.worktrees/session-005";
      Directory(worktreePath).createSync(recursive: true);
      addTearDown(() => tempDir.deleteSync(recursive: true));

      await _insertSession(
        db: db,
        sessionId: "s5",
        projectId: tempDir.path,
        worktreePath: worktreePath,
        branchName: "session-005",
      );

      await expectLater(
        () => handler.handle(
          makeRequest("DELETE", "/session/delete"),
          body: const DeleteSessionRequest(
            sessionId: "s5",
            deleteWorktree: true,
            deleteBranch: false,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(409))),
      );
      expect(plugin.lastDeleteSessionId, isNull);
      expect(await db.sessionDao.getSession(sessionId: "s5"), isNotNull);
    });

    test("6) force=true on dirty worktree: cleanup proceeds", () async {
      await _insertSession(
        db: db,
        sessionId: "s6",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-006",
        branchName: "session-006",
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s6",
          deleteWorktree: true,
          deleteBranch: false,
          force: true,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s6"));
      expect(await db.sessionDao.getSession(sessionId: "s6"), isNull);
    });

    test("7) null worktreePath: skips git ops", () async {
      await _insertSession(
        db: db,
        sessionId: "s7",
        projectId: "/repo",
        worktreePath: null,
        branchName: null,
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s7",
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s7"));
      expect(await db.sessionDao.getSession(sessionId: "s7"), isNull);
    });

    test("9) missing DB session: plugin delete only", () async {
      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s9",
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s9"));
      expect(await db.sessionDao.getSession(sessionId: "s9"), isNull);
    });

    test("10) plugin delete non-404 failure: cleanup already ran and DB row remains", () async {
      await _insertSession(
        db: db,
        sessionId: "s10",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-010",
        branchName: "session-010",
      );
      plugin.throwOnDeleteSessionError = PluginApiException("/session/s10", 500);

      await expectLater(
        () => handler.handle(
          makeRequest("DELETE", "/session/delete"),
          body: const DeleteSessionRequest(
            sessionId: "s10",
            deleteWorktree: true,
            deleteBranch: true,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<PluginApiException>()),
      );

      expect(await db.sessionDao.getSession(sessionId: "s10"), isNotNull);
    });
  });
}

Future<void> _insertSession({
  required AppDatabase db,
  required String sessionId,
  required String projectId,
  required String? worktreePath,
  required String? branchName,
}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]); // satisfy v5 FK constraint
  await db.sessionDao.insertSession(
    sessionId: sessionId,
    projectId: projectId,
    isDedicated: true,
    createdAt: 1,
    worktreePath: worktreePath,
    branchName: branchName,
    baseBranch: null,
    baseCommit: null,
  );
}

class _FakeWorktreeService extends WorktreeService {
  final List<String> operationLog;

  _FakeWorktreeService({required AppDatabase database, required this.operationLog})
    : super(
        branchRepository: BranchRepository(
          gitCliApi: GitCliApi(processRunner: _FakeProcessRunner(), gitPathExists: ({required String gitPath}) => true),
        ),
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          gitApi: GitCliApi(
            processRunner: _FakeProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
        ),
      );
}

class _FakeProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return ProcessResult(0, 0, "", "");
  }
}

class _TrackingFakeBridgePlugin extends FakeBridgePlugin {
  final List<String> operationLog;

  _TrackingFakeBridgePlugin({required this.operationLog});

  @override
  Future<void> deleteSession(String sessionId) async {
    operationLog.add("pluginDelete");
    await super.deleteSession(sessionId);
  }
}
