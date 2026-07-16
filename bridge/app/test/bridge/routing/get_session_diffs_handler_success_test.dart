import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/git_diff_output_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/session_diff_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_diffs_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_diff_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "get_session_diffs_handler_test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionDiffsHandler success", () {
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
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      processRunner = FakeProcessRunner();
      final filesystemRepository = FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      );
      handler = GetSessionDiffsHandler(
        sessionDiffService: SessionDiffService(
          sessionRepository: sessionRepository,
          sessionDiffRepository: SessionDiffRepository(
            gitCliApi: GitCliApi(
              processRunner: processRunner,
              gitPathExists: ({required String gitPath}) => true,
            ),
            outputMapper: const GitDiffOutputMapper(),
          ),
          filesystemRepository: filesystemRepository,
        ),
      );
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

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",

        lastAgent: null,
        lastAgentModel: null,
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (FakeProcessRunner.supportGitDiffCalls(arguments) case final result?) {
          return result;
        }
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
            "M\x00lib/modified.dart\x00A\x00lib/added.dart\x00D\x00lib/deleted.dart\x00",
            "",
          );
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(
            1,
            0,
            "5\t2\tlib/modified.dart\x008\t0\tlib/added.dart\x000\t3\tlib/deleted.dart\x00",
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

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",

        lastAgent: null,
        lastAgentModel: null,
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (FakeProcessRunner.supportGitDiffCalls(arguments) case final result?) {
          return result;
        }
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.contains("--name-status")) {
          return ProcessResult(1, 0, "M\x00lib/kept.dart\x00M\x00lib/model.freezed.dart\x00", "");
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(1, 0, "1\t0\tlib/kept.dart\x0010\t2\tlib/model.freezed.dart\x00", "");
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

    test("includes untracked files", () async {
      File("${tempDir.path}/lib/untracked.dart")
        ..createSync(recursive: true)
        ..writeAsStringSync("new file\n");

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",

        lastAgent: null,
        lastAgentModel: null,
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (FakeProcessRunner.supportGitDiffCalls(
              arguments,
              untrackedOutput: "lib/untracked.dart\x00",
            )
            case final result?) {
          return result;
        }
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.contains("--name-status")) {
          return ProcessResult(1, 0, "", "");
        }
        if (arguments.contains("--numstat")) {
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
      expect(body, hasLength(1));
      final entry = body.single as Map<String, dynamic>;
      expect(entry["file"], equals("lib/untracked.dart"));
      expect(entry["status"], equals("added"));
      expect(entry["runtimeType"], equals("content"));
      expect(entry["before"], equals(""));
      expect(entry["after"], equals("new file\n"));
      expect(entry["additions"], equals(1));
    });

    test("returns skipped diff for binary file", () async {
      File("${tempDir.path}/assets/blob.dat")
        ..createSync(recursive: true)
        ..writeAsBytesSync([0, 159, 146, 150]);

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",

        lastAgent: null,
        lastAgentModel: null,
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (FakeProcessRunner.supportGitDiffCalls(arguments) case final result?) {
          return result;
        }
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.contains("--name-status")) {
          return ProcessResult(1, 0, "M\x00assets/blob.dat\x00", "");
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(1, 0, "-\t-\tassets/blob.dat\x00", "");
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

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]); // satisfy v5 FK constraint
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "s1",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "main",

        lastAgent: null,
        lastAgentModel: null,
      );

      processRunner.responder = ({required List<String> arguments}) {
        if (FakeProcessRunner.supportGitDiffCalls(arguments) case final result?) {
          return result;
        }
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.contains("--name-status")) {
          return ProcessResult(1, 0, "M\x00lib/too_large.dart\x00", "");
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(1, 0, "1\t1\tlib/too_large.dart\x00", "");
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

    test("uses UTF-8 bytes for the combined content limit", () async {
      final before = List.filled(30000, "😀").join();
      final after = List.filled(30000, "🚀").join();
      File("${tempDir.path}/lib/unicode.dart")
        ..createSync(recursive: true)
        ..writeAsStringSync(after);
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]);
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "unicode-session",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "unicode-session",
        baseBranch: "main",
        baseCommit: "main",
        lastAgent: null,
        lastAgentModel: null,
      );
      processRunner.responder = ({required List<String> arguments}) {
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.contains("--name-status")) {
          return ProcessResult(1, 0, "M\x00lib/unicode.dart\x00", "");
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(1, 0, "1\t1\tlib/unicode.dart\x00", "");
        }
        if (arguments.first == "ls-files") {
          return ProcessResult(1, 0, "", "");
        }
        if (arguments.first == "cat-file") {
          return ProcessResult(1, 0, "120000\n", "");
        }
        if (arguments.first == "show") {
          return ProcessResult(1, 0, before, "");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "unicode-session")),
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
    });

    test("skips an oversized base blob without invoking git show", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project-1"]);
      await db.sessionDao.insertSession(
        pluginId: "opencode",
        sessionId: "large-base-session",
        projectId: "project-1",
        isDedicated: true,
        createdAt: 123,
        worktreePath: tempDir.path,
        branchName: "large-base-session",
        baseBranch: "main",
        baseCommit: "main",
        lastAgent: null,
        lastAgentModel: null,
      );
      processRunner.responder = ({required List<String> arguments}) {
        if (arguments.length >= 2 && arguments[0] == "rev-parse" && arguments[1] == "--verify") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.length >= 2 && arguments[0] == "merge-base") {
          return ProcessResult(1, 0, "abc123\n", "");
        }
        if (arguments.contains("--name-status")) {
          return ProcessResult(1, 0, "D\x00lib/large.dart\x00", "");
        }
        if (arguments.contains("--numstat")) {
          return ProcessResult(1, 0, "0\t300000\tlib/large.dart\x00", "");
        }
        if (arguments.first == "ls-files") {
          return ProcessResult(1, 0, "", "");
        }
        if (arguments.first == "cat-file") {
          return ProcessResult(1, 0, "300000\n", "");
        }
        if (arguments.first == "show") {
          return ProcessResult(1, 0, List.filled(300000, "x").join(), "");
        }
        throw StateError("Unexpected git call: $arguments");
      };

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/session/diffs",
          body: jsonEncode(const SessionIdRequest(sessionId: "large-base-session")),
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
      expect(
        processRunner.invocations.where((invocation) => invocation.arguments.first == "show"),
        isEmpty,
      );
    });
  });
}
