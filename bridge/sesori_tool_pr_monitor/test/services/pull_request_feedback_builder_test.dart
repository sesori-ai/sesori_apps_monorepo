import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:test/test.dart";

import "../support/pull_request_builders.dart";

void main() {
  test("nothing awaiting a reply says so", () {
    final answered = emptySnapshot.copyWith(
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: true,
          comments: [
            comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z"),
            agentReply(id: "thread-1-comment-2", at: "2026-08-03T11:05:00Z"),
          ],
        ),
      ],
    );

    expect(
      feedback.build(target: target, snapshot: answered),
      "No feedback on sesori/example#42 is awaiting a reply.",
    );
  });

  test("lists the comments since the latest agent reply in each unanswered channel", () {
    final snapshot = emptySnapshot.copyWith(
      reviewThreads: [
        thread(
          id: "thread-1",
          isResolved: false,
          comments: [
            comment(id: "thread-1-comment-1", author: "reviewer", at: "2026-08-03T11:00:00Z"),
            agentReply(id: "thread-1-comment-2", at: "2026-08-03T11:05:00Z"),
            comment(
              id: "thread-1-comment-3",
              author: "owner",
              at: "2026-08-03T11:10:00Z",
            ).copyWith(origin: PullRequestCommentOrigin.local, body: "Rename this.\n<!-- hidden -->Thanks"),
          ],
        ).copyWith(path: "lib/a.dart", line: 7),
        thread(
          id: "thread-2",
          isResolved: true,
          comments: [
            comment(id: "thread-2-comment-1", author: "review-bot", at: "2026-08-03T11:00:00Z").copyWith(
              isBot: true,
              body: "<!-- only a marker -->",
            ),
          ],
        ),
      ],
      issueComments: [
        comment(id: "issue-1", author: "alice", at: "2026-08-03T11:20:00Z").copyWith(body: "x" * 4001),
        agentReply(id: "issue-2", at: "2026-08-03T11:00:00Z"),
      ],
      reviewSummaries: [
        // Same second as the agent reply: still unanswered, listed first.
        comment(id: "review-1", author: "bob", at: "2026-08-03T11:00:00Z").copyWith(body: "Looks off."),
      ],
    );

    const closing =
        'Answer each channel with reply_on_pr(pr: "sesori/example#42", thread_id: "<thread id>", body: "...") '
        "or omit thread_id for a PR comment; the reply prefix is added for you. A non-actionable bot "
        "acknowledgement needs no reply: use mark_pr_ready instead.";

    expect(
      feedback.build(target: target, snapshot: snapshot),
      [
        "Feedback on sesori/example#42 awaiting a reply (3 channels):",
        "",
        "### Thread `thread-1` on lib/a.dart:7 (unresolved)",
        "",
        "**owner** (local account, unprefixed: a human instruction, 2026-08-03T11:10:00.000Z):",
        "> Rename this.",
        "> Thanks",
        "",
        "### Thread `thread-2` (resolved, bot-only)",
        "",
        "**review-bot** (bot, 2026-08-03T11:00:00.000Z):",
        "> (no text)",
        "",
        "### PR comments and review summaries (reply without `thread_id`)",
        "",
        "**bob** (human, 2026-08-03T11:00:00.000Z):",
        "> Looks off.",
        "",
        "**alice** (human, 2026-08-03T11:20:00.000Z):",
        "> ${"x" * 4000}",
        "> [truncated]",
        "",
        closing,
      ].join("\n"),
    );
  });
}
