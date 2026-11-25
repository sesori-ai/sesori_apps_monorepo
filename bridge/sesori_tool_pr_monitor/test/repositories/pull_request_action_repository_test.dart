import "dart:async";
import "dart:convert";

import "package:sesori_tool_pr_monitor/src/api/gh_cli_api.dart";
import "package:sesori_tool_pr_monitor/src/models/gh_cli_exception.dart";
import "package:sesori_tool_pr_monitor/src/models/pull_request_not_open_exception.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_merge_outcome.dart";
import "package:sesori_tool_pr_monitor/src/repositories/pull_request_action_repository.dart";
import "package:test/test.dart";

import "../support/fake_command_executor.dart";
import "../support/pull_request_builders.dart";

void main() {
  late FakeCommandExecutor executor;
  late PullRequestActionRepository actions;

  setUp(() {
    executor = FakeCommandExecutor();
    actions = PullRequestActionRepository(api: GhCliApi(commandExecutor: executor));
  });

  void enqueuePullRequest({required String state, required bool merged, required String headSha}) =>
      executor.enqueueStdout(
        stdout: jsonEncode({
          "state": state,
          "merged": merged,
          "title": "test PR",
          "head": {"sha": headSha},
        }),
      );

  Future<PullRequestMergeOutcome> merge() => actions.squashMerge(target: target, headSha: "head-1", title: "test PR");

  group("squashMerge", () {
    test("pins the accepted head with a title-only squash, then adds the merged label", () async {
      executor
        ..enqueueStdout(stdout: '{"merged": true, "message": "Pull Request successfully merged"}')
        ..enqueueStdout(stdout: "{}")
        ..enqueueStdout(stdout: "[]");

      expect(await merge(), isA<PullRequestMerged>().having((outcome) => outcome.labelError, "labelError", isNull));
      expect(executor.invocations.first.arguments, [
        "api",
        "--hostname",
        "github.com",
        "--method",
        "PUT",
        "repos/sesori/example/pulls/42/merge",
        "-f",
        "merge_method=squash",
        "-f",
        "sha=head-1",
        "-f",
        "commit_title=test PR",
        "-f",
        "commit_message=",
      ]);
      expect(executor.invocations[1].field(field: "name"), PullRequestActionRepository.mergedLabel);
      expect(executor.invocations[2].arguments.sublist(3), [
        "repos/sesori/example/issues/42/labels",
        "-f",
        "labels[]=automatically-merged",
      ]);
    });

    test("an answer that did not merge is a rejection with GitHub's reason", () async {
      executor.enqueueStdout(stdout: '{"merged": false, "message": "Required review is missing"}');

      expect(
        await merge(),
        isA<PullRequestMergeRejected>().having((outcome) => outcome.reason, "reason", "Required review is missing"),
      );
      expect(executor.invocations, hasLength(1));
    });

    test("a definitive HTTP rejection keeps GitHub's reason without reconciling", () async {
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Required review is missing (HTTP 405)");

      expect(
        await merge(),
        isA<PullRequestMergeRejected>().having((outcome) => outcome.reason, "reason", contains("Required review")),
      );
      expect(executor.invocations, hasLength(1));
    });

    test("HTTP 409 means the accepted head changed", () async {
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Head branch was modified (HTTP 409)");

      expect(
        await merge(),
        isA<PullRequestMergeHeadChanged>().having((outcome) => outcome.actualHeadSha, "actualHeadSha", isNull),
      );
      expect(executor.invocations, hasLength(1));
    });

    test("an indeterminate answer reconciles a merged accepted head as success", () async {
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Bad Gateway (HTTP 502)");
      enqueuePullRequest(state: "closed", merged: true, headSha: "head-1");
      executor
        ..enqueueStdout(stdout: "{}")
        ..enqueueStdout(stdout: "[]");

      expect(await merge(), isA<PullRequestMerged>());
      expect(executor.invocations[1].arguments, ["api", "--hostname", "github.com", "repos/sesori/example/pulls/42"]);
      expect(executor.invocations, hasLength(4));
    });

    test("an indeterminate answer is unknown when the accepted head cannot be proven merged", () async {
      executor.enqueueError(error: TimeoutException("slow"));
      enqueuePullRequest(state: "closed", merged: false, headSha: "head-1");
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Bad Gateway (HTTP 502)");
      enqueuePullRequest(state: "closed", merged: true, headSha: "head-2");

      expect(
        await merge(),
        isA<PullRequestMergeOutcomeUnknown>().having(
          (outcome) => outcome.detail,
          "detail",
          contains("observed CLOSED at head head-1"),
        ),
      );
      expect(
        await merge(),
        isA<PullRequestMergeOutcomeUnknown>().having(
          (outcome) => outcome.detail,
          "detail",
          contains("observed MERGED at head head-2"),
        ),
      );
    });

    test("a failed reconciliation is still unknown", () async {
      executor
        ..enqueueFailure(exitCode: 1, stderr: "gh: Bad Gateway (HTTP 502)")
        ..enqueueFailure(exitCode: 1, stderr: "gh: Service Unavailable (HTTP 503)");

      expect(
        await merge(),
        isA<PullRequestMergeOutcomeUnknown>().having(
          (outcome) => outcome.detail,
          "detail",
          contains("the follow-up PR query failed"),
        ),
      );
    });

    test("reconciliation finds an open PR at another head as a changed head", () async {
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Bad Gateway (HTTP 502)");
      enqueuePullRequest(state: "open", merged: false, headSha: "head-2");

      expect(
        await merge(),
        isA<PullRequestMergeHeadChanged>().having((outcome) => outcome.actualHeadSha, "actualHeadSha", "head-2"),
      );
    });

    test("a merge stays a success when the merged label cannot be added", () async {
      executor
        ..enqueueStdout(stdout: '{"merged": true, "message": "merged"}')
        ..enqueueFailure(exitCode: 1, stderr: "gh: Validation Failed (HTTP 422)")
        ..enqueueFailure(exitCode: 1, stderr: "gh: Resource not accessible by integration (HTTP 403)");

      expect(
        await merge(),
        isA<PullRequestMerged>().having(
          (outcome) => outcome.labelError,
          "labelError",
          isA<GhCliCommandFailedException>(),
        ),
      );
    });
  });

  group("ready label", () {
    test("adding checks the PR is open, creates the label with its color, then adds it", () async {
      enqueuePullRequest(state: "open", merged: false, headSha: "head-1");
      executor
        ..enqueueFailure(exitCode: 1, stderr: "gh: Validation Failed (HTTP 422)")
        ..enqueueStdout(stdout: "[]");

      await actions.addReadyLabel(target: target);

      expect(executor.invocations[1].field(field: "color"), "0e8a16");
      expect(executor.invocations[2].field(field: "labels[]"), "agent-ready");
    });

    test("a merged or closed PR is never labelled, since labels share the issue namespace", () async {
      enqueuePullRequest(state: "closed", merged: true, headSha: "head-1");

      await expectLater(
        actions.addReadyLabel(target: target),
        throwsA(isA<PullRequestNotOpenException>().having((error) => error.message, "message", contains("merged"))),
      );
      expect(executor.invocations, hasLength(1));
    });

    test("removing reports whether the PR carried the label", () async {
      enqueuePullRequest(state: "open", merged: false, headSha: "head-1");
      executor.enqueueStdout(stdout: "[]");
      enqueuePullRequest(state: "open", merged: false, headSha: "head-1");
      executor.enqueueFailure(exitCode: 1, stderr: "gh: Label does not exist (HTTP 404)");

      expect(await actions.removeReadyLabel(target: target), isTrue);
      expect(executor.invocations[1].arguments.sublist(3), [
        "--method",
        "DELETE",
        "repos/sesori/example/issues/42/labels/agent-ready",
      ]);
      expect(await actions.removeReadyLabel(target: target), isFalse);
    });
  });

  group("reply", () {
    test("a PR comment gets the reply prefix once and returns its URL", () async {
      executor
        ..enqueueStdout(stdout: "https://github.com/sesori/example/pull/42#issuecomment-1\n")
        ..enqueueStdout(stdout: "https://github.com/sesori/example/pull/42#issuecomment-2\n");

      expect(
        await actions.reply(target: target, threadId: null, body: "Fixed."),
        "https://github.com/sesori/example/pull/42#issuecomment-1",
      );
      await actions.reply(target: target, threadId: null, body: "[Sesori reply] Done.");

      expect(executor.invocations[0].field(field: "body"), "[Sesori reply] Fixed.");
      expect(executor.invocations[1].field(field: "body"), "[Sesori reply] Done.");
    });

    test("a thread reply goes through GraphQL to that thread", () async {
      executor.enqueueStdout(
        stdout: jsonEncode({
          "data": {
            "addPullRequestReviewThreadReply": {
              "comment": {"url": "https://github.com/sesori/example/pull/42#discussion_r1"},
            },
          },
        }),
      );

      expect(
        await actions.reply(target: target, threadId: "PRRT_1", body: "Fixed."),
        "https://github.com/sesori/example/pull/42#discussion_r1",
      );
      expect(executor.invocations.single.field(field: "thread"), "PRRT_1");
      expect(executor.invocations.single.field(field: "body"), "[Sesori reply] Fixed.");
    });
  });
}
