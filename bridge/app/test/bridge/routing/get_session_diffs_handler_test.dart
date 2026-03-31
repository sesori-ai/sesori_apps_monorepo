import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_diffs_handler.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionDiffsHandler", () {
    late AppDatabase db;
    late SessionDao sessionDao;
    late _FakeProcessRunner processRunner;
    late GetSessionDiffsHandler handler;
    late Directory tempDir;

    setUp(() async {
      db = createTestDatabase();
      sessionDao = db.sessionDao;
      processRunner = _FakeProcessRunner();
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

    test("returns [] when session is missing", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session/missing/diff"),
        pathParams: {"id": "missing"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, equals("[]"));
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

    test("returns [] when base commit is unreachable", () async {
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
        if (arguments.first == "rev-parse") {
          return ProcessResult(1, 128, "", "fatal: bad revision");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, equals("[]"));
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

    test("happy path returns file diffs", () async {
      File("${tempDir.path}/lib/modified.dart")
        ..createSync(recursive: true)
        ..writeAsStringSync("modified after\n");
      File("${tempDir.path}/lib/added.dart")
        ..createSync(recursive: true)
        ..writeAsStringSync("added after\n");

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
        if (arguments.length >= 4 && arguments[0] == "diff" && arguments[3] == "--name-status") {
          return ProcessResult(
            1,
            0,
            "M\tlib/modified.dart\nA\tlib/added.dart\nD\tlib/deleted.dart\n",
            "",
          );
        }
        if (arguments.length >= 4 && arguments[0] == "diff" && arguments[3] == "--numstat") {
          return ProcessResult(
            1,
            0,
            "5\t2\tlib/modified.dart\n8\t0\tlib/added.dart\n0\t3\tlib/deleted.dart\n",
            "",
          );
        }
        if (arguments.length >= 2 && arguments[0] == "show") {
          if (arguments[1] == "abc123:lib/modified.dart") {
            return ProcessResult(1, 0, "modified before\n", "");
          }
          if (arguments[1] == "abc123:lib/deleted.dart") {
            return ProcessResult(1, 0, "deleted before\n", "");
          }
          return ProcessResult(1, 128, "", "fatal");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      final body = switch (jsonDecode(response.body!)) {
        final List<dynamic> list => list,
        _ => throw StateError("expected JSON list"),
      };
      expect(body, hasLength(3));

      final byFile = <String, Map<String, dynamic>>{
        for (final item in body) (item as Map<String, dynamic>)["file"] as String: item,
      };

      expect(byFile["lib/modified.dart"]?["status"], equals("modified"));
      expect(byFile["lib/modified.dart"]?["before"], equals("modified before\n"));
      expect(byFile["lib/modified.dart"]?["after"], equals("modified after\n"));
      expect(byFile["lib/modified.dart"]?["additions"], equals(5));
      expect(byFile["lib/modified.dart"]?["deletions"], equals(2));

      expect(byFile["lib/added.dart"]?["status"], equals("added"));
      expect(byFile["lib/added.dart"]?["before"], equals(""));
      expect(byFile["lib/added.dart"]?["after"], equals("added after\n"));

      expect(byFile["lib/deleted.dart"]?["status"], equals("deleted"));
      expect(byFile["lib/deleted.dart"]?["before"], equals("deleted before\n"));
      expect(byFile["lib/deleted.dart"]?["after"], equals(""));
    });

    test("filters generated files", () async {
      File("${tempDir.path}/lib/kept.dart")
        ..createSync(recursive: true)
        ..writeAsStringSync("after\n");

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
        if (arguments.length >= 4 && arguments[0] == "diff" && arguments[3] == "--name-status") {
          return ProcessResult(1, 0, "M\tlib/kept.dart\nM\tlib/model.freezed.dart\n", "");
        }
        if (arguments.length >= 4 && arguments[0] == "diff" && arguments[3] == "--numstat") {
          return ProcessResult(1, 0, "1\t0\tlib/kept.dart\n10\t2\tlib/model.freezed.dart\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "show") {
          return ProcessResult(1, 0, "before\n", "");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/diff"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      final body = switch (jsonDecode(response.body!)) {
        final List<dynamic> list => list,
        _ => throw StateError("expected JSON list"),
      };
      expect(body, hasLength(1));
      expect((body.single as Map<String, dynamic>)["file"], equals("lib/kept.dart"));
    });
  });
}

class _Invocation {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  const _Invocation({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });
}

class _FakeProcessRunner {
  ProcessResult Function({required List<String> arguments}) responder = _defaultResponder;
  final List<_Invocation> invocations = <_Invocation>[];

  Future<ProcessResult> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    invocations.add(
      _Invocation(
        executable: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
      ),
    );
    return responder(arguments: arguments);
  }

  static ProcessResult _defaultResponder({required List<String> arguments}) {
    throw StateError("Unexpected git call: $arguments");
  }
}
