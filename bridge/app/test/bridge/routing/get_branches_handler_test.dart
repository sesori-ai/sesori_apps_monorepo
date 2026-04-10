import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/branch_repository.dart";
import "package:sesori_bridge/src/bridge/routing/get_branches_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetBranchesHandler", () {
    late GetBranchesHandler handler;

    setUp(() {
      final runner = _FakeProcessRunner();
      final repo = BranchRepository(gitCliApi: GitCliApi(processRunner: runner));
      handler = GetBranchesHandler(repo);
    });

    test("canHandle POST /project/branches", () {
      expect(handler.canHandle(makeRequest("POST", "/project/branches")), isTrue);
    });

    test("does not handle GET /project/branches", () {
      expect(handler.canHandle(makeRequest("GET", "/project/branches")), isFalse);
    });

    test("does not handle POST /project", () {
      expect(handler.canHandle(makeRequest("POST", "/project")), isFalse);
    });

    test("returns branches from repository", () async {
      final result = await handler.handle(
        makeRequest("POST", "/project/branches"),
        body: const ProjectIdRequest(projectId: "/repo"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result, isA<BranchListResponse>());
      expect(result.currentBranch, isNotNull);
    });

    test("response is JSON-serializable", () async {
      final result = await handler.handle(
        makeRequest("POST", "/project/branches"),
        body: const ProjectIdRequest(projectId: "/repo"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      // Verify the result can be serialized to JSON without errors
      final json = jsonEncode(result);
      expect(json, isNotEmpty);

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded, contains("branches"));
    });
  });
}

class _FakeProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // git branch -a → two branches
    if (arguments.contains("branch") && arguments.contains("-a")) {
      return ProcessResult(0, 0, "main 1700000000\ndev 1700000100\n", "");
    }
    // git worktree list --porcelain → main worktree
    if (arguments.contains("worktree") && arguments.contains("list")) {
      return ProcessResult(0, 0, "worktree /repo\nbranch refs/heads/main\n\n", "");
    }
    // git rev-parse --abbrev-ref HEAD → main
    if (arguments.contains("--abbrev-ref")) {
      return ProcessResult(0, 0, "main\n", "");
    }
    return ProcessResult(0, 0, "", "");
  }
}
