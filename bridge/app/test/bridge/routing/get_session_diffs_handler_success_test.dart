import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/daos/session_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_diffs_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "get_session_diffs_handler_test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionDiffsHandler success", () {
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
      tempDir = await Directory.systemTemp.createTemp("session_diff_handler_success_test_");
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
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
          return ProcessResult(
            1,
            0,
            "M\tlib/modified.dart\nA\tlib/added.dart\nD\tlib/deleted.dart\n",
            "",
          );
        }
        if (arguments.contains("--numstat")) {
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
      final body = switch (jsonDecode(response.body!)) {
        {"diffs": final List<dynamic> list} => list,
        _ => throw StateError("expected JSON object with diffs"),
      };
      expect(body, hasLength(3));

      final byFile = <String, Map<String, dynamic>>{
        for (final item in body) (item as Map<String, dynamic>)["file"] as String: item,
      };

      expect(byFile["lib/modified.dart"]?["status"], equals("modified"));
      expect(byFile["lib/modified.dart"]?["runtimeType"], equals("content"));
      expect(byFile["lib/modified.dart"]?["before"], equals("modified before\n"));
      expect(byFile["lib/modified.dart"]?["after"], equals("modified after\n"));
      expect(byFile["lib/modified.dart"]?["additions"], equals(5));
      expect(byFile["lib/modified.dart"]?["deletions"], equals(2));

      expect(byFile["lib/added.dart"]?["status"], equals("added"));
      expect(byFile["lib/added.dart"]?["runtimeType"], equals("content"));
      expect(byFile["lib/added.dart"]?["before"], equals(""));
      expect(byFile["lib/added.dart"]?["after"], equals("added after\n"));

      expect(byFile["lib/deleted.dart"]?["status"], equals("deleted"));
      expect(byFile["lib/deleted.dart"]?["runtimeType"], equals("content"));
      expect(byFile["lib/deleted.dart"]?["before"], equals("deleted before\n"));
      expect(byFile["lib/deleted.dart"]?["after"], equals(""));

      final nameStatusCall = processRunner.invocations.where((call) => call.arguments.contains("--name-status"));
      final numstatCall = processRunner.invocations.where((call) => call.arguments.contains("--numstat"));
      expect(nameStatusCall.single.arguments, contains("--no-renames"));
      expect(numstatCall.single.arguments, contains("--no-renames"));
    });

    test("includes generated files too", () async {
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
          return ProcessResult(1, 0, "M\tlib/kept.dart\nM\tlib/model.freezed.dart\n", "");
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(1, 0, "1\t0\tlib/kept.dart\n10\t2\tlib/model.freezed.dart\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "show") {
          return ProcessResult(1, 0, "before\n", "");
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

      final body = switch (jsonDecode(response.body!)) {
        {"diffs": final List<dynamic> list} => list,
        _ => throw StateError("expected JSON object with diffs"),
      };
      expect(body, hasLength(2));
      expect(
        body.map((dynamic item) => (item as Map<String, dynamic>)["file"] as String).toSet(),
        equals({"lib/kept.dart", "lib/model.freezed.dart"}),
      );
    });

    test("returns skipped diff for binary file", () async {
      File("${tempDir.path}/assets/blob.dat")
        ..createSync(recursive: true)
        ..writeAsBytesSync([0, 159, 146, 150]);

      await sessionDao.insertSession(
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
          return ProcessResult(1, 0, "M\tassets/blob.dat\n", "");
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(1, 0, "-\t-\tassets/blob.dat\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "show") {
          return ProcessResult(1, 0, "", "");
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

      final body = switch (jsonDecode(response.body!)) {
        {"diffs": final List<dynamic> list} => list,
        _ => throw StateError("expected JSON object with diffs"),
      };
      final entry = body.single as Map<String, dynamic>;
      expect(entry["runtimeType"], equals("skipped"));
      expect(entry["reason"], equals("binary"));
      expect(entry["status"], equals("modified"));
      expect(entry.containsKey("before"), isFalse);
      expect(entry.containsKey("after"), isFalse);
    });

    test("returns skipped diff when combined content exceeds 200KB", () async {
      final beforeLarge = List.filled(120 * 1024, "a").join();
      final afterLarge = List.filled(120 * 1024, "b").join();
      File("${tempDir.path}/lib/too_large.dart")
        ..createSync(recursive: true)
        ..writeAsStringSync(afterLarge);

      await sessionDao.insertSession(
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
          return ProcessResult(1, 0, "M\tlib/too_large.dart\n", "");
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(1, 0, "1\t1\tlib/too_large.dart\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "show") {
          return ProcessResult(1, 0, beforeLarge, "");
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

      final body = switch (jsonDecode(response.body!)) {
        {"diffs": final List<dynamic> list} => list,
        _ => throw StateError("expected JSON object with diffs"),
      };
      final entry = body.single as Map<String, dynamic>;
      expect(entry["runtimeType"], equals("skipped"));
      expect(entry["reason"], equals("tooLarge"));
      expect(entry["status"], equals("modified"));
    });
  });
}
