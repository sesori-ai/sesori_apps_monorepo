import "package:sesori_tool_pr_monitor/src/models/pull_request_target.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_activity_calculator.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_feedback_builder.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_readiness_calculator.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_report_builder.dart";

// Synthetic data shaped like the plugin's core.test.ts helpers.

const PullRequestTarget target = PullRequestTarget(owner: "sesori", repo: "example", number: 42);

const PullRequestActivityCalculator activity = PullRequestActivityCalculator();
const PullRequestReadinessCalculator readiness = PullRequestReadinessCalculator(activity: activity);
const PullRequestReportBuilder reports = PullRequestReportBuilder(activity: activity, readiness: readiness);
const PullRequestFeedbackBuilder feedback = PullRequestFeedbackBuilder(readiness: readiness);

/// An open, mergeable PR with no CI, reviews, comments or labels.
const PullRequestSnapshot emptySnapshot = PullRequestSnapshot(
  title: "test PR",
  url: "https://github.com/sesori/example/pull/42",
  state: PullRequestState.open,
  mergeable: PullRequestMergeable.mergeable,
  headSha: "head-1",
  checks: [],
  reviews: [],
  reviewSummaries: [],
  pendingReviewers: [],
  reviewThreads: [],
  issueCommentsTotal: 0,
  issueComments: [],
  labels: [],
);

/// A human comment from someone other than the local account.
PullRequestComment comment({required String id, required String author, required String at}) => PullRequestComment(
  id: id,
  author: author,
  isBot: false,
  createdAt: DateTime.parse(at),
  body: "Synthetic comment $id.",
  origin: PullRequestCommentOrigin.other,
  reviewState: null,
);

/// A prefixed reply from the local account.
PullRequestComment agentReply({required String id, required String at}) => comment(
  id: id,
  author: "owner",
  at: at,
).copyWith(origin: PullRequestCommentOrigin.agentReply, body: "$sesoriReplyPrefix Done.");

PullRequestReviewThread thread({
  required String id,
  required bool isResolved,
  required List<PullRequestComment> comments,
}) => PullRequestReviewThread(id: id, isResolved: isResolved, path: null, line: null, comments: comments);

PullRequestCheck check({required String name, required PullRequestCheckOutcome outcome}) =>
    PullRequestCheck(id: "check-run-$name", name: name, outcome: outcome);
