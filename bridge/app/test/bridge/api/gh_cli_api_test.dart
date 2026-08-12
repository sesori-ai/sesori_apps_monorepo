import "dart:async";
import "dart:collection";
import "dart:io";

import "package:sesori_bridge/src/api/gh_pull_request_batch.dart";
import "package:sesori_bridge/src/bridge/api/gh_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _githubRepositoryIdentity = "sesori-ai/sesori_apps_monorepo";

void main() {
  group("GhCliApi.isAvailable", () {
    late _FakeProcessRunner processRunner;
    late GhCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      service = GhCliApi(processRunner: processRunner);
    });

    test("returns true when gh --version exits with code 0", () async {
      processRunner.enqueueResult(result: _ok(stdout: "gh version 2.0.0\n"));

      final isAvailable = await service.isAvailable();

      expect(isAvailable, isTrue);
      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.first.command, equals("gh"));
      expect(processRunner.invocations.first.arguments, equals(["--version"]));
      expect(processRunner.invocations.first.workingDirectory, isNull);
    });

    test("returns false on non-zero exit code", () async {
      processRunner.enqueueResult(result: _fail(exitCode: 1));

      final isAvailable = await service.isAvailable();

      expect(isAvailable, isFalse);
    });

    test("propagates timeout", () async {
      processRunner.enqueueError(error: TimeoutException("timed out"));

      await expectLater(service.isAvailable(), throwsA(isA<TimeoutException>()));
    });

    test("returns false on ProcessException", () async {
      processRunner.enqueueError(
        error: const ProcessException("gh", <String>["--version"], "boom", 1),
      );

      final isAvailable = await service.isAvailable();

      expect(isAvailable, isFalse);
    });

    test("reports a missing optional gh installation only once", () async {
      final stderrLines = <String>[];
      processRunner
        ..enqueueError(
          error: const ProcessException("gh", <String>["--version"], "No such file or directory", 2),
        )
        ..enqueueError(
          error: const ProcessException("gh", <String>["--version"], "No such file or directory", 2),
        );

      await IOOverrides.runZoned(
        () async {
          expect(await service.isAvailable(), isFalse);
          expect(await service.isAvailable(), isFalse);
        },
        stderr: () => _CapturingStdout(stderrLines),
      );

      expect(stderrLines, hasLength(1));
      expect(
        stderrLines.single,
        allOf(
          contains("GitHub CLI (gh) is not installed or is unavailable on PATH"),
          contains("GitHub pull request and CI status sync is disabled"),
          isNot(contains("worktree")),
          isNot(contains("ProcessException")),
        ),
      );
    });
  });

  group("GhCliApi.isAuthenticated", () {
    late _FakeProcessRunner processRunner;
    late GhCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      service = GhCliApi(processRunner: processRunner);
    });

    test("returns true when gh auth status exits with code 0", () async {
      processRunner.enqueueResult(result: _ok());

      final isAuthenticated = await service.isAuthenticated();

      expect(isAuthenticated, isTrue);
      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.first.command, equals("gh"));
      expect(
        processRunner.invocations.first.arguments,
        equals(["auth", "status", "--hostname", "github.com"]),
      );
    });

    test("returns false on non-zero exit code", () async {
      processRunner.enqueueResult(result: _fail(exitCode: 1));

      final isAuthenticated = await service.isAuthenticated();

      expect(isAuthenticated, isFalse);
    });

    test("propagates timeout", () async {
      processRunner.enqueueError(error: TimeoutException("timed out"));

      await expectLater(service.isAuthenticated(), throwsA(isA<TimeoutException>()));
    });

    test("reports an ambiguous auth failure without claiming the user is unauthenticated", () async {
      final stderrLines = <String>[];
      processRunner
        ..enqueueResult(result: _fail(exitCode: 1, stderr: "network is unreachable"))
        ..enqueueResult(result: _fail(exitCode: 1, stderr: "network is unreachable"));

      await IOOverrides.runZoned(
        () async {
          expect(await service.isAuthenticated(), isFalse);
          expect(await service.isAuthenticated(), isFalse);
        },
        stderr: () => _CapturingStdout(stderrLines),
      );

      expect(stderrLines, hasLength(1));
      expect(
        stderrLines.single,
        allOf(
          contains("GitHub CLI (gh) could not verify authentication for github.com"),
          contains("gh auth status --hostname github.com"),
          contains("authentication and connectivity"),
          isNot(contains("is not authenticated")),
          isNot(contains("gh auth login")),
          isNot(contains("worktree")),
        ),
      );
    });

    for (final diagnostic in const [
      (name: "no configured GitHub hosts", stderr: "You are not logged into any GitHub hosts"),
      (name: "no configured github.com account", stderr: "You are not logged into any accounts on github.com"),
    ]) {
      test("reports known unauthentication for ${diagnostic.name}", () async {
        final stderrLines = <String>[];
        processRunner
          ..enqueueResult(result: _fail(exitCode: 1, stderr: diagnostic.stderr))
          ..enqueueResult(result: _fail(exitCode: 1, stderr: diagnostic.stderr));

        await IOOverrides.runZoned(
          () async {
            expect(await service.isAuthenticated(), isFalse);
            expect(await service.isAuthenticated(), isFalse);
          },
          stderr: () => _CapturingStdout(stderrLines),
        );

        expect(stderrLines, hasLength(1));
        expect(
          stderrLines.single,
          allOf(
            contains("GitHub CLI (gh) is not authenticated for github.com"),
            contains("gh auth login"),
            contains("GH_TOKEN/GITHUB_TOKEN"),
            isNot(contains("could not verify authentication")),
          ),
        );
      });
    }
  });

  group("GhCliApi.getAuthenticatedIdentity", () {
    late _FakeProcessRunner processRunner;
    late GhCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      service = GhCliApi(processRunner: processRunner);
    });

    test("returns the raw login from the github.com user endpoint", () async {
      processRunner.enqueueResult(result: _ok(stdout: "  OctoCat\n"));

      final identity = await service.getAuthenticatedIdentity();

      expect(identity.rawLogin, "  OctoCat\n");
      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.single.command, "gh");
      expect(
        processRunner.invocations.single.arguments,
        ["api", "--hostname", "github.com", "user", "--jq", ".login"],
      );
      expect(processRunner.invocations.single.workingDirectory, isNull);
    });

    test("throws a process failure when the identity command fails", () async {
      processRunner.enqueueResult(result: _fail(exitCode: 1));

      await expectLater(
        service.getAuthenticatedIdentity(),
        throwsA(
          isA<ProcessException>()
              .having((error) => error.executable, "executable", "gh")
              .having((error) => error.errorCode, "errorCode", 1),
        ),
      );
    });

    test("preserves an empty login for repository validation", () async {
      processRunner.enqueueResult(result: _ok(stdout: "  \n"));

      expect((await service.getAuthenticatedIdentity()).rawLogin, "  \n");
    });

    test("propagates a process failure for the caller to handle", () async {
      processRunner.enqueueError(
        error: const ProcessException("gh", <String>["api"], "boom", 1),
      );

      await expectLater(
        service.getAuthenticatedIdentity(),
        throwsA(isA<ProcessException>()),
      );
    });

    test("propagates timeout for the caller to handle", () async {
      processRunner.enqueueError(error: TimeoutException("timed out"));

      await expectLater(
        service.getAuthenticatedIdentity(),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group("GhCliApi pull request GraphQL", () {
    late _FakeProcessRunner processRunner;
    late GhCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      service = GhCliApi(processRunner: processRunner);
    });

    test("queries typed open and terminal pages with variable-bound targets", () async {
      processRunner.enqueueResult(
        result: _ok(
          stdout: _batchJson(
            pages: [
              _pageJson(
                stateGroup: "open",
                nodes: [
                  _pullRequestJson(
                    number: 1,
                    state: "OPEN",
                    branch: "feat/one",
                    createdAt: "2026-08-01T10:00:00Z",
                    statusCheckRollup: "SUCCESS",
                  ),
                ],
              ),
              _pageJson(stateGroup: "terminal", nodes: const []),
            ],
          ),
        ),
      );

      final response = await service.queryInitialPullRequestPages(
        targets: const [
          GhPullRequestTarget(
            repositoryOwner: "sesori-ai",
            repositoryName: "sesori_apps_monorepo",
            branchName: "feat/one",
          ),
        ],
      );

      expect(response.viewerLogin, "OctoCat");
      expect(response.pages, hasLength(2));
      final pullRequest = response.pages.first.connection.nodes.single;
      expect(pullRequest.number, 1);
      expect(pullRequest.createdAt, DateTime.utc(2026, 8, 1, 10));
      expect(pullRequest.statusCheckRollup, PrCheckStatus.success);

      expect(processRunner.invocations, hasLength(1));
      final invocation = processRunner.invocations.single;
      expect(invocation.command, "gh");
      expect(invocation.workingDirectory, isNull);
      expect(invocation.arguments.take(4), ["api", "graphql", "--hostname", "github.com"]);
      final queryArgument = invocation.arguments.singleWhere((argument) => argument.startsWith("query="));
      expect(
        queryArgument,
        contains(r"target0: repository(owner: $owner0, name: $name0, followRenames: true)"),
      );
      expect(queryArgument, contains("states: [OPEN]"));
      expect(queryArgument, contains("states: [MERGED, CLOSED]"));
      expect(queryArgument, contains("createdAt"));
      expect(queryArgument, isNot(contains("feat/one")));
      expect(invocation.arguments, containsAll(["owner0=sesori-ai", "name0=sesori_apps_monorepo", "branch0=feat/one"]));
    });

    test("queries one typed cursor page for its requested state group", () async {
      processRunner.enqueueResult(
        result: _ok(
          stdout: _batchJson(
            pages: [_pageJson(stateGroup: "terminal", nodes: const [])],
          ),
        ),
      );

      final response = await service.queryPullRequestCursorPages(
        requests: const [
          GhPullRequestCursorRequest(
            target: GhPullRequestTarget(
              repositoryOwner: "sesori-ai",
              repositoryName: "sesori_apps_monorepo",
              branchName: "feat/one",
            ),
            stateGroup: GhPullRequestStateGroup.terminal,
            cursor: "cursor-1",
          ),
        ],
      );

      expect(response.pages.single.stateGroup, GhPullRequestStateGroup.terminal);
      final arguments = processRunner.invocations.single.arguments;
      final queryArgument = arguments.singleWhere((argument) => argument.startsWith("query="));
      expect(
        queryArgument,
        contains(r"target0: repository(owner: $owner0, name: $name0, followRenames: true)"),
      );
      expect(queryArgument, contains("states: [MERGED, CLOSED]"));
      expect(queryArgument, contains(r"after: $cursor0"));
      expect(arguments, contains("cursor0=cursor-1"));
    });

    test("parses nullable GraphQL PR fields into closed enums and no checks", () async {
      processRunner.enqueueResult(
        result: _ok(
          stdout: _batchJson(
            pages: [
              _pageJson(
                stateGroup: "open",
                nodes: [
                  _pullRequestJson(
                    number: 2,
                    state: "CLOSED",
                    branch: "feat/one",
                    createdAt: "2026-08-01T10:00:00Z",
                    mergeable: "CONFLICTING",
                    reviewDecision: null,
                    statusCheckRollup: null,
                  ),
                ],
              ),
              _pageJson(stateGroup: "terminal", nodes: const []),
            ],
          ),
        ),
      );

      final response = await service.queryInitialPullRequestPages(targets: const [_target]);
      final pullRequest = response.pages.first.connection.nodes.single;
      expect(pullRequest.state, PrState.closed);
      expect(pullRequest.mergeable, PrMergeableStatus.conflicting);
      expect(pullRequest.reviewDecision, PrReviewDecision.unknown);
      expect(pullRequest.statusCheckRollup, PrCheckStatus.none);
    });

    test("throws a typed failure for GraphQL errors and nonzero exits", () async {
      processRunner
        ..enqueueResult(
          result: _ok(stdout: _batchJson(errorCount: 1, pages: const [])),
        )
        ..enqueueResult(result: _fail(exitCode: 1))
        ..enqueueError(error: TimeoutException("query timed out"));

      await expectLater(
        service.queryInitialPullRequestPages(targets: const [_target]),
        throwsA(
          isA<GhPullRequestGraphqlException>()
              .having((error) => error.errorCount, "errors", 1)
              .having((error) => error.toString(), "presentation", contains("1 GraphQL error")),
        ),
      );
      await expectLater(
        service.queryInitialPullRequestPages(targets: const [_target]),
        throwsA(
          isA<GhPullRequestProcessExitException>()
              .having((error) => error.exitCode, "exit", 1)
              .having((error) => error.toString(), "presentation", contains("exit code 1")),
        ),
      );
      await expectLater(
        service.queryInitialPullRequestPages(targets: const [_target]),
        throwsA(
          isA<GhPullRequestWrappedException>()
              .having((error) => error.innerError, "innerError", isA<TimeoutException>())
              .having((error) => error.toString(), "presentation", contains("TimeoutException"))
              .having((error) => error.toString(), "presentation", isNot(contains("query timed out")))
              .having((error) => error.toString(), "presentation", isNot(contains("feat/one"))),
        ),
      );
    });

    test("rejects malformed output and batches larger than twenty", () async {
      processRunner.enqueueResult(result: _ok(stdout: "not-json"));

      await expectLater(
        service.queryInitialPullRequestPages(targets: const [_target]),
        throwsA(
          isA<GhPullRequestWrappedException>()
              .having((error) => error.innerError, "innerError", isA<FormatException>())
              .having((error) => error.toString(), "presentation", contains("FormatException"))
              .having((error) => error.toString(), "presentation", isNot(contains("not-json"))),
        ),
      );
      expect(
        () => service.queryInitialPullRequestPages(
          targets: List<GhPullRequestTarget>.filled(21, _target),
        ),
        throwsArgumentError,
      );
    });
  });
}

const _target = GhPullRequestTarget(
  repositoryOwner: "sesori-ai",
  repositoryName: "sesori_apps_monorepo",
  branchName: "feat/one",
);

String _batchJson({
  int errorCount = 0,
  required List<String> pages,
}) {
  return '{"errorCount":$errorCount,"viewerLogin":"OctoCat","pages":[${pages.join(",")}]}';
}

String _pageJson({
  required String stateGroup,
  required List<String> nodes,
  bool hasNextPage = false,
  String? endCursor,
}) {
  final cursorJson = endCursor == null ? "null" : '"$endCursor"';
  return '{"requestIndex":0,"stateGroup":"$stateGroup","repositoryIdentity":"$_githubRepositoryIdentity",'
      '"connection":{"nodes":[${nodes.join(",")}],"pageInfo":{"hasNextPage":$hasNextPage,'
      '"endCursor":$cursorJson}}}';
}

String _pullRequestJson({
  required int number,
  required String state,
  required String branch,
  required String createdAt,
  String mergeable = "MERGEABLE",
  String? reviewDecision = "APPROVED",
  String? statusCheckRollup = "SUCCESS",
  bool isCrossRepository = false,
}) {
  final reviewJson = reviewDecision == null ? "null" : '"$reviewDecision"';
  final statusJson = statusCheckRollup == null ? "null" : '"$statusCheckRollup"';
  return '{"number":$number,"url":"https://example/pr/$number","title":"PR $number", '
      '"createdAt":"$createdAt","state":"$state","headRefName":"$branch",'
      '"isCrossRepository":$isCrossRepository,"mergeable":"$mergeable",'
      '"reviewDecision":$reviewJson,"statusCheckRollup":$statusJson}';
}

ProcessResult _ok({String stdout = "", String stderr = ""}) {
  return ProcessResult(1, 0, stdout, stderr);
}

ProcessResult _fail({required int exitCode, String stderr = ""}) {
  return ProcessResult(1, exitCode, "", stderr);
}

class const _Invocation({
    required this.command,
    required this.arguments,
    required this.workingDirectory,
  }) {
  final String command;
  final List<String> arguments;
  final String? workingDirectory;
}

class _FakeProcessRunner() implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  final List<_Invocation> invocations = <_Invocation>[];
  final Queue<Object> _queue = Queue<Object>();

  void enqueueResult({required ProcessResult result}) {
    _queue.add(result);
  }

  void enqueueError({required Object error}) {
    _queue.add(error);
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    invocations.add(
      _Invocation(
        command: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
      ),
    );

    if (_queue.isEmpty) {
      throw StateError("No queued process output for: $executable $arguments");
    }

    final output = _queue.removeFirst();
    if (output is ProcessResult) {
      return output;
    }
    throw output;
  }
}

class _CapturingStdout(this.lines) implements Stdout {
  final List<String> lines;

  @override
  bool get supportsAnsiEscapes => false;

  @override
  void writeln([Object? object = ""]) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
