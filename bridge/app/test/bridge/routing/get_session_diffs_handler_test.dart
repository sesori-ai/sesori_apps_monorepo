import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_diffs_handler.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "get_session_diffs_handler_test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionDiffsHandler errors", () {
    late AppDatabase db;
    late SessionDao sessionDao;
    late FakeProcessRunner processRunner;
    late GetSessionDiffsHandler handler;
    late Directory tempDir;

    setUp(() async {
      db = createTestDatabase();
      sessionDao = db.sessionDao;
      processRunner = FakeProcessRunner();
      handler = GetSessionDiffsHandler(sessionDao, processRunner: processRunner.call);
      tempDir = await Directory.systemTemp.createTemp("session_diff_handler_test_");
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("canHandle accepts GET /session/:id/diff", () {
      expect(handler.canHandle(makeRequest("GET", "/session/s1/diff")), isTrue);
    });

    test("canHandle rejects other method and path", () {
      expect(handler.canHandle(makeRequest("POST", "/session/s1/diff")), isFalse);
      expect(handler.canHandle(makeRequest("GET", "/session/s1/message")), isFalse);
    });

    test("returns 404 when session is missing", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/missing/diff"),
        pathParams: {"id": "missing"},
        queryParams: {},
      );

      expect(response.status, equals(404));
      expect(response.body, equals("session not found: missing"));
      expect(processRunner.invocations, isEmpty);
    });

    test("returns [] when session has null worktreePath", () async {
      await sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: null,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, equals("[]"));
      expect(processRunner.invocations, isEmpty);
    });

    test("returns [] when session has null baseCommit", () async {
      await sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: null,
      );

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, equals("[]"));
      expect(processRunner.invocations, isEmpty);
    });

    test("returns [] when worktree directory does not exist", () async {
      await sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: "${tempDir.path}/does-not-exist",
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, equals("[]"));
      expect(processRunner.invocations, isEmpty);
    });

    test("returns 422 when base commit is unreachable", () async {
      await sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 128, "", "fatal: bad revision");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(422));
      expect(response.body, equals("base commit 'abc123' is not reachable"));
    });

    test("returns 500 when git diff fails", () async {
      await sessionDao.insertSession(
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123",
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.contains("--name-status")) {
          return ProcessResult(1, 128, "", "fatal: bad object");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(500));
      expect(response.body, equals("git diff --name-status failed"));
    });

    test("returns 400 when session id is missing", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session//diff"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, equals("missing session id"));
    });
  });
}
