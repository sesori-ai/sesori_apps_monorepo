import "dart:convert";

import "package:sesori_tool_pr_monitor/src/api/gh_cli_api.dart";
import "package:sesori_tool_pr_monitor/src/api/gh_cli_exception.dart";
import "package:sesori_tool_pr_monitor/src/models/pull_request_target.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:sesori_tool_pr_monitor/src/repositories/pull_request_snapshot_repository.dart";
import "package:test/test.dart";

import "../support/fake_command_executor.dart";

const _target = PullRequestTarget(owner: "octo-org", repo: "widget", number: 42);

void main() {
  late FakeCommandExecutor executor;
  late PullRequestSnapshotRepository repository;

  setUp(() {
    executor = FakeCommandExecutor();
    repository = PullRequestSnapshotRepository(api: GhCliApi(commandExecutor: executor));
  });

  void enqueueFullPoll() {
    executor
      ..enqueueFixture(name: "pull_request_first_page.json")
      ..enqueueFixture(name: "checks_page_2.json")
      ..enqueueFixture(name: "latest_reviews_page_2.json")
      ..enqueueFixture(name: "review_threads_page_2.json")
      ..enqueueFixture(name: "labels_page_2.json");
  }

  Future<PullRequestSnapshot> fetch() => repository.fetchSnapshot(target: _target, selfLogin: "sesori-dev");

  group("a full poll", () {
    test("follows every overflowing connection with its cursor", () async {
      enqueueFullPoll();

      await fetch();

      final pages = executor.invocations.skip(1).toList();
      expect(
        [for (final page in pages) page.field(field: "cursor")],
        [
          "checks-1",
          "reviews-1",
          "threads-1",
          "labels-1",
        ],
      );
      expect(pages.first.field(field: "head"), "0123456789abcdef0123456789abcdef01234567");
    });

    test("maps the pull request fields", () async {
      enqueueFullPoll();

      final snapshot = await fetch();

      expect(snapshot.title, "Add widget sizing");
      expect(snapshot.url, "https://github.com/octo-org/widget/pull/42");
      expect(snapshot.state, PullRequestState.open);
      expect(snapshot.mergeable, PullRequestMergeable.mergeable);
      expect(snapshot.headSha, "0123456789abcdef0123456789abcdef01234567");
      expect(snapshot.labels, ["agent-ready", "Needs-Review"]);
      expect(snapshot.pendingReviewers, ["reviewer-a", "core-team", "review-bot"]);
    });

    test("maps CheckRun and StatusContext outcomes and drops unknown context kinds", () async {
      enqueueFullPoll();

      final snapshot = await fetch();

      expect(
        {for (final check in snapshot.checks) check.name: check.outcome},
        {
          "build": PullRequestCheckOutcome.success,
          "lint": PullRequestCheckOutcome.failure,
          "e2e": PullRequestCheckOutcome.pending,
          "ci/legacy": PullRequestCheckOutcome.pending,
          "deploy": PullRequestCheckOutcome.failure,
          "docs": PullRequestCheckOutcome.success,
          "bench": PullRequestCheckOutcome.success,
          "slow": PullRequestCheckOutcome.failure,
          "queued": PullRequestCheckOutcome.pending,
          "ci/expected": PullRequestCheckOutcome.pending,
          "coverage": PullRequestCheckOutcome.success,
          "security": PullRequestCheckOutcome.failure,
        },
      );
      expect(snapshot.checks.first.id, "CR_build");
      expect(
        snapshot.checks.firstWhere((check) => check.name == "ci/legacy").id,
        "status:ci/legacy:2026-11-20T10:00:00.000Z",
      );
    });

    test("keeps submitted reviews with an author and picks the review summaries", () async {
      enqueueFullPoll();

      final snapshot = await fetch();

      expect(
        [for (final review in snapshot.reviews) (review.login, review.state)],
        [
          ("reviewer-b", PullRequestReviewState.approved),
          ("reviewer-c", PullRequestReviewState.changesRequested),
          ("review-bot", PullRequestReviewState.commented),
          ("reviewer-e", PullRequestReviewState.changesRequested),
        ],
      );
      // An empty changes-requested review counts; a blank body with inline
      // comments does not.
      expect([for (final summary in snapshot.reviewSummaries) summary.id], ["R_changes", "R_bot"]);
      final botSummary = snapshot.reviewSummaries.last;
      expect(botSummary.isBot, isTrue);
      expect(botSummary.createdAt, DateTime.utc(2026, 11, 20, 11, 10));
      expect(botSummary.reviewState, isNull);
    });

    test("maps review threads with the current or original line", () async {
      enqueueFullPoll();

      final snapshot = await fetch();

      final [first, second] = snapshot.reviewThreads;
      expect((first.id, first.isResolved, first.path, first.line), ("T_one", false, "lib/widget.dart", 10));
      expect((second.id, second.isResolved, second.path, second.line), ("T_two", true, "lib/sizing.dart", 7));
      expect(first.comments.first.reviewState, PullRequestReviewState.changesRequested);
      expect(second.comments.single.author, "ghost");
      expect(second.comments.single.origin, PullRequestCommentOrigin.other);
    });

    test("classifies local comments and agent replies case-insensitively", () async {
      enqueueFullPoll();

      final snapshot = await fetch();

      final threadReply = snapshot.reviewThreads.first.comments.last;
      expect(threadReply.origin, PullRequestCommentOrigin.agentReply);
      expect(
        {for (final comment in snapshot.issueComments) comment.id: comment.origin},
        {
          "IC_reviewer": PullRequestCommentOrigin.other,
          "IC_reply": PullRequestCommentOrigin.agentReply,
          "IC_unprefixed": PullRequestCommentOrigin.local,
          "IC_spoof": PullRequestCommentOrigin.other,
        },
      );
    });

    test("counts issue comments without the agent's replies", () async {
      enqueueFullPoll();

      final snapshot = await fetch();

      expect(snapshot.issueCommentsTotal, 4);
    });
  });

  test("a commit without CI has no checks and fetches no check pages", () async {
    executor.enqueueStdout(
      stdout: _pullRequestJson(statusCheckRollup: null, commentsTotal: 0, comments: const [], mergeable: "MERGEABLE"),
    );

    final snapshot = await fetch();

    expect(snapshot.checks, isEmpty);
    expect(executor.invocations, hasLength(1));
  });

  test("the issue-comment count never goes below zero", () async {
    executor.enqueueStdout(
      stdout: _pullRequestJson(
        statusCheckRollup: null,
        commentsTotal: 0,
        mergeable: "MERGEABLE",
        comments: [
          {
            "id": "IC",
            "author": {"login": "sesori-dev", "__typename": "User"},
            "body": "[Sesori reply] ok",
            "createdAt": "2026-11-20T12:00:00Z",
          },
        ],
      ),
    );

    expect((await fetch()).issueCommentsTotal, 0);
  });

  test("mergeable state UNKNOWN maps to unknown", () async {
    executor.enqueueStdout(
      stdout: _pullRequestJson(statusCheckRollup: null, commentsTotal: 0, comments: const [], mergeable: "UNKNOWN"),
    );

    expect((await fetch()).mergeable, PullRequestMergeable.unknown);
  });

  group("pagination failures", () {
    test("a repeated cursor fails the poll", () async {
      executor
        ..enqueueFixture(name: "pull_request_first_page.json")
        ..enqueueStdout(stdout: _checksPage(hasNextPage: true, endCursor: "checks-1"));

      await expectLater(
        fetch(),
        throwsA(
          isA<PullRequestPaginationException>()
              .having((e) => e.problem, "problem", PullRequestPaginationProblem.invalidCursor)
              .having((e) => e.message, "message", "GitHub returned an invalid check-context pagination cursor"),
        ),
      );
    });

    test("a next page without a cursor fails the poll", () async {
      executor
        ..enqueueFixture(name: "pull_request_first_page.json")
        ..enqueueStdout(stdout: _checksPage(hasNextPage: true, endCursor: null));

      await expectLater(
        fetch(),
        throwsA(
          isA<PullRequestPaginationException>().having(
            (e) => e.problem,
            "problem",
            PullRequestPaginationProblem.invalidCursor,
          ),
        ),
      );
    });

    test("a head commit that vanished mid-poll is retryable", () async {
      executor
        ..enqueueFixture(name: "pull_request_first_page.json")
        ..enqueueStdout(stdout: '{"data": {"repository": {"object": null}}}');

      await expectLater(
        fetch(),
        throwsA(
          isA<PullRequestPaginationException>().having(
            (e) => e.problem,
            "problem",
            PullRequestPaginationProblem.connectionVanished,
          ),
        ),
      );
    });

    test("a PR that vanished mid-poll is not found", () async {
      executor
        ..enqueueFixture(name: "pull_request_first_page.json")
        ..enqueueFixture(name: "checks_page_2.json")
        ..enqueueFixture(name: "pull_request_missing.json");

      await expectLater(fetch(), throwsA(isA<GhCliNotFoundException>()));
    });

    test("an errors payload on a follow-up page is retryable", () async {
      executor
        ..enqueueFixture(name: "pull_request_first_page.json")
        ..enqueueFixture(name: "pull_request_graphql_errors.json");

      await expectLater(fetch(), throwsA(isA<GhCliGraphQlException>()));
    });
  });
}

String _checksPage({required bool hasNextPage, required String? endCursor}) => jsonEncode({
  "data": {
    "repository": {
      "object": {
        "statusCheckRollup": {
          "contexts": {
            "pageInfo": {"hasNextPage": hasNextPage, "endCursor": endCursor},
            "nodes": <Object?>[],
          },
        },
      },
    },
  },
});

String _pullRequestJson({
  required Object? statusCheckRollup,
  required int commentsTotal,
  required List<Map<String, Object?>> comments,
  required String mergeable,
}) {
  final emptyPage = {
    "pageInfo": {"hasNextPage": false, "endCursor": null},
    "nodes": <Object?>[],
  };
  return jsonEncode({
    "data": {
      "repository": {
        "pullRequest": {
          "title": "T",
          "url": "https://github.com/octo-org/widget/pull/42",
          "state": "OPEN",
          "mergeable": mergeable,
          "headRefOid": "abc",
          "commits": {
            "nodes": [
              {
                "commit": {"statusCheckRollup": statusCheckRollup},
              },
            ],
          },
          "reviewRequests": {"nodes": <Object?>[]},
          "latestReviews": emptyPage,
          "reviewThreads": emptyPage,
          "comments": {"totalCount": commentsTotal, "nodes": comments},
          "labels": emptyPage,
        },
      },
    },
  });
}
