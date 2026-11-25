import "dart:async";
import "dart:io";

import "package:sesori_tool_pr_monitor/src/api/gh_cli_api.dart";
import "package:sesori_tool_pr_monitor/src/api/models/gh_pull_request_dto.dart";
import "package:sesori_tool_pr_monitor/src/models/gh_cli_exception.dart";
import "package:sesori_tool_pr_monitor/src/models/pull_request_target.dart";
import "package:test/test.dart";

import "../support/fake_command_executor.dart";

const _target = PullRequestTarget(owner: "octo-org", repo: "widget", number: 42);

void main() {
  late FakeCommandExecutor executor;
  late GhCliApi api;

  setUp(() {
    executor = FakeCommandExecutor();
    api = GhCliApi(commandExecutor: executor);
  });

  group("fetchAuthenticatedLogin", () {
    test("returns the trimmed login from gh api user", () async {
      executor.enqueueStdout(stdout: "sesori-dev\n");

      expect(await api.fetchAuthenticatedLogin(), "sesori-dev");
      final invocation = executor.invocations.single;
      expect(invocation.executable, "gh");
      expect(invocation.arguments, ["api", "--hostname", "github.com", "user", "--jq", ".login"]);
      expect(invocation.timeout, GhCliApi.commandTimeout);
    });

    test("rejects an empty login", () async {
      executor.enqueueStdout(stdout: "\n");

      await expectLater(api.fetchAuthenticatedLogin(), throwsA(isA<GhCliInvalidResponseException>()));
    });
  });

  group("fetchPullRequest", () {
    test("sends the poll query with typed variables and a 60 s timeout", () async {
      executor.enqueueFixture(name: "pull_request_first_page.json");

      final pullRequest = await api.fetchPullRequest(target: _target);

      expect(pullRequest.title, "Add widget sizing");
      expect(pullRequest.state, GhPullRequestStateDto.open);
      final invocation = executor.invocations.single;
      expect(invocation.arguments.take(4), ["api", "graphql", "--hostname", "github.com"]);
      expect(invocation.field(field: "query"), contains("reviewThreads(first: 100)"));
      expect(invocation.field(field: "owner"), "octo-org");
      expect(invocation.field(field: "repo"), "widget");
      expect(invocation.arguments, containsAllInOrder(["-F", "number=42"]));
      expect(invocation.arguments, containsAllInOrder(["-f", "owner=octo-org"]));
      expect(invocation.timeout, const Duration(seconds: 60));
    });

    test("treats a clean payload without the PR as not found", () async {
      executor.enqueueFixture(name: "pull_request_missing.json");

      await expectLater(api.fetchPullRequest(target: _target), throwsA(isA<GhCliNotFoundException>()));
    });

    test("treats a GraphQL errors array as retryable even with data present", () async {
      executor.enqueueFixture(name: "pull_request_graphql_errors.json");

      await expectLater(
        api.fetchPullRequest(target: _target),
        throwsA(
          isA<GhCliGraphQlException>().having(
            (error) => error.message,
            "message",
            "GitHub returned an incomplete GraphQL response: API rate limit exceeded; unknown GraphQL error",
          ),
        ),
      );
    });

    test("wraps non-JSON output", () async {
      executor.enqueueStdout(stdout: "<html>oops</html>");

      await expectLater(
        api.fetchPullRequest(target: _target),
        throwsA(isA<GhCliInvalidResponseException>().having((e) => e.innerError, "innerError", isA<FormatException>())),
      );
    });

    test("wraps a payload of the wrong shape", () async {
      executor.enqueueStdout(stdout: '{"data": {"repository": {"pullRequest": {"title": 3}}}}');

      await expectLater(api.fetchPullRequest(target: _target), throwsA(isA<GhCliInvalidResponseException>()));
    });
  });

  group("page queries", () {
    test("the check-context page asks for the head commit, not the PR number", () async {
      executor.enqueueFixture(name: "checks_page_2.json");

      final page = await api.fetchCheckContextsPage(target: _target, headSha: "abc", cursor: "checks-1");

      expect(page?.nodes, hasLength(7));
      final invocation = executor.invocations.single;
      expect(invocation.field(field: "head"), "abc");
      expect(invocation.field(field: "cursor"), "checks-1");
      expect(invocation.field(field: "number"), isNull);
      expect(invocation.field(field: "query"), contains(r"object(oid: $head)"));
    });

    test("the check-context page is null when the commit is gone", () async {
      executor.enqueueStdout(stdout: '{"data": {"repository": {"object": null}}}');

      expect(await api.fetchCheckContextsPage(target: _target, headSha: "abc", cursor: "checks-1"), isNull);
    });

    test("a PR page whose PR vanished is not found", () async {
      executor.enqueueFixture(name: "pull_request_missing.json");

      await expectLater(
        api.fetchLabelsPage(target: _target, cursor: "labels-1"),
        throwsA(isA<GhCliNotFoundException>()),
      );
    });
  });

  group("failures", () {
    test("a missing gh binary is unavailable and keeps the original error", () async {
      const original = ProcessException("gh", ["api"], "No such file or directory", 2);
      executor.enqueueError(error: original);

      await expectLater(
        api.fetchPullRequest(target: _target),
        throwsA(
          isA<GhCliUnavailableException>()
              .having((e) => e.innerError, "innerError", same(original))
              .having((e) => e.message, "message", contains("https://cli.github.com")),
        ),
      );
    });

    test("a timeout is its own failure", () async {
      final original = TimeoutException("gh timed out");
      executor.enqueueError(error: original);

      await expectLater(
        api.fetchPullRequest(target: _target),
        throwsA(
          isA<GhCliTimedOutException>()
              .having((e) => e.timeout, "timeout", GhCliApi.commandTimeout)
              .having((e) => e.innerError, "innerError", same(original)),
        ),
      );
    });

    test("gh's authentication-required exit code is unauthenticated", () async {
      executor.enqueueFailure(exitCode: 4, stderr: "To get started with GitHub CLI, please run:  gh auth login\n");

      await expectLater(
        api.fetchAuthenticatedLogin(),
        throwsA(isA<GhCliUnauthenticatedException>().having((e) => e.message, "message", contains("gh auth login"))),
      );
    });

    test("HTTP 401 is unauthenticated", () async {
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Bad credentials (HTTP 401)");

      await expectLater(api.fetchPullRequest(target: _target), throwsA(isA<GhCliUnauthenticatedException>()));
    });

    test("an unresolvable repository is not found", () async {
      executor.enqueueFailure(
        exitCode: 1,
        stderr: "gh: Could not resolve to a Repository with the name 'octo-org/widget'.",
      );

      await expectLater(
        api.fetchPullRequest(target: _target),
        throwsA(isA<GhCliNotFoundException>().having((e) => e.detail, "detail", contains("octo-org/widget"))),
      );
    });

    test("HTTP 404 is not found", () async {
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Not Found (HTTP 404)");

      await expectLater(api.fetchPullRequest(target: _target), throwsA(isA<GhCliNotFoundException>()));
    });

    test("an unresolvable host is a retryable failure, not a missing PR", () async {
      executor.enqueueFailure(exitCode: 1, stderr: "error connecting to api.github.com\ncould not resolve host");

      await expectLater(
        api.fetchPullRequest(target: _target),
        throwsA(isA<GhCliCommandFailedException>().having((e) => e.httpStatus, "httpStatus", isNull)),
      );
    });

    test("a server error keeps its HTTP status", () async {
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Server Error (HTTP 502)");

      await expectLater(
        api.fetchPullRequest(target: _target),
        throwsA(
          isA<GhCliCommandFailedException>()
              .having((e) => e.httpStatus, "httpStatus", 502)
              .having((e) => e.exitCode, "exitCode", 1),
        ),
      );
    });

    test("a silent failure names its exit code", () async {
      executor.enqueueFailure(exitCode: 3, stderr: "  ");

      await expectLater(
        api.fetchPullRequest(target: _target),
        throwsA(isA<GhCliCommandFailedException>().having((e) => e.detail, "detail", "exit code 3")),
      );
    });
  });
}
