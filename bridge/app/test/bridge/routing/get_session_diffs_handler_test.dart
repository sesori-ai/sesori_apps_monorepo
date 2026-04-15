import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_diffs_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "get_session_diffs_handler_test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionDiffsHandler errors", () {
    late AppDatabase db;
    late SessionRepository sessionRepository;
    late FakeProcessRunner processRunner;
    late GetSessionDiffsHandler handler;
    late Directory tempDir;

    setUp(() async {
      db = createTestDatabase();
      sessionRepository = SessionRepository(
        plugin: FakeBridgePlugin(),
        sessionDao: db.sessionDao,
        pullRequestRepository: PullRequestRepository(
          pullRequestDao: db.pullRequestDao,
          projectsDao: db.projectsDao,
        ),
      );
      processRunner = FakeProcessRunner();
      handler = GetSessionDiffsHandler(
        sessionRepository: sessionRepository,
        processRunner: processRunner,
      );
      tempDir = await Directory.systemTemp.createTemp("session_diff_handler_test_");
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("canHandle accepts POST /session/diffs", () {
      expect(handler.canHandle(makeRequest("POST", "/session/diffs")), isTrue);
    });

    test("canHandle rejects other method and path", () {
      expect(handler.canHandle(makeRequest("GET", "/session/diffs")), isFalse);
      expect(handler.canHandle(makeRequest("POST", "/session/s1/diff")), isFalse);
    });

    test("returns 404 when session is missing", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "missing")),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(404));
      expect(response.body, equals("session not found: missing"));
      expect(processRunner.invocations, isEmpty);
    });

    test("returns empty diffs when session has null worktreePath", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: null,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",
      );

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "s1")),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(response.body, equals('{"diffs":[]}'));
      expect(processRunner.invocations, isEmpty);
    });

    test("returns empty diffs when session has null baseBranch", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: null,
        baseCommit: null,
      );

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "s1")),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(response.body, equals('{"diffs":[]}'));
      expect(processRunner.invocations, isEmpty);
    });

    test("returns empty diffs when worktree directory does not exist", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: "${tempDir.path}/does-not-exist",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",
      );

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "s1")),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(response.body, equals('{"diffs":[]}'));
      expect(processRunner.invocations, isEmpty);
    });

    test("returns 422 when base branch is unreachable", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 128, "", "fatal: bad revision");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "s1")),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(422));
      expect(response.body, equals("base branch 'main' is not reachable"));
    });

    test("returns 422 when merge-base finds no common ancestor", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 1, "", "fatal: no common ancestor");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "s1")),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(422));
      expect(response.body, contains("no common ancestor"));
    });

    test("returns 500 when merge-base returns unexpected multi-line output", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 0, "abc123\ndef456\n", "");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "s1")),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(500));
      expect(response.body, contains("unexpected output"));
    });

    test("returns 500 when git diff fails", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.contains("--name-status")) {
          return ProcessResult(1, 128, "", "fatal: bad object");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "s1")),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(500));
      expect(response.body, equals("git diff --name-status failed"));
    });

    test("returns 400 when request body is missing", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/session/diffs"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
      expect(response.body, equals("Bad Request: missing JSON body"));
    });

    test("returns 400 when sessionId is missing in body", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/session/diffs", body: "{}"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
      expect(response.body, contains("Bad Request: invalid JSON body"));
    });
  });
}
