import "../repositories/models/pull_request_baseline.dart";
import "../repositories/models/pull_request_ci_phase.dart";
import "../repositories/models/pull_request_snapshot.dart";

/// Decides whether two consecutive polls of a PR differ in a way worth
/// reporting (spec §4).
class const PullRequestActivityCalculator() {
  PullRequestCiPhase ciPhase({required PullRequestSnapshot snapshot}) {
    if (snapshot.checks.isEmpty) return PullRequestCiPhase.none;
    return snapshot.checks.any((check) => check.outcome == PullRequestCheckOutcome.pending)
        ? PullRequestCiPhase.running
        : PullRequestCiPhase.concluded;
  }

  /// Every comment except the agent's own prefixed replies.
  List<PullRequestComment> relevantComments({required List<PullRequestComment> comments}) =>
      comments.where((comment) => comment.origin != PullRequestCommentOrigin.agentReply).toList();

  bool hasAddedRelevantComment({
    required List<PullRequestComment> previous,
    required List<PullRequestComment> next,
  }) {
    final before = {for (final comment in previous) comment.id};
    return next.any(
      (comment) => comment.origin != PullRequestCommentOrigin.agentReply && !before.contains(comment.id),
    );
  }

  bool reviewThreadsReceivedNewComments({
    required List<PullRequestReviewThread> previous,
    required List<PullRequestReviewThread> next,
  }) {
    final before = {for (final thread in previous) thread.id: thread};
    return next.any(
      (thread) => hasAddedRelevantComment(previous: before[thread.id]?.comments ?? const [], next: thread.comments),
    );
  }

  /// True when a conflict is newly observed, including after an initial
  /// UNKNOWN. [lastDefiniteMergeable] is the last MERGEABLE or CONFLICTING
  /// value seen, or null when there was none yet.
  bool hasNewMergeConflict({
    required PullRequestMergeable? lastDefiniteMergeable,
    required PullRequestSnapshot next,
  }) =>
      next.state == PullRequestState.open &&
      next.mergeable == PullRequestMergeable.conflicting &&
      lastDefiniteMergeable != PullRequestMergeable.conflicting;

  /// True when [next] shows a failing check that [previous] did not, even
  /// while CI still runs. Every failure on a new head is new.
  bool hasNewCiFailure({required PullRequestSnapshot previous, required PullRequestSnapshot next}) {
    final failing = next.checks.where((check) => check.outcome == PullRequestCheckOutcome.failure);
    if (failing.isEmpty) return false;
    if (previous.headSha != next.headSha) return true;
    final before = _failedCheckIds(snapshot: previous).toSet();
    return failing.any((check) => !before.contains(check.id));
  }

  /// What a report on [snapshot] covers, as a watch stores it.
  PullRequestBaseline baselineOf({required PullRequestSnapshot snapshot}) => PullRequestBaseline(
    state: snapshot.state,
    headSha: snapshot.headSha,
    mergeable: snapshot.mergeable,
    ciPhase: ciPhase(snapshot: snapshot),
    failedCheckIds: _failedCheckIds(snapshot: snapshot).toSet(),
    reviewSignature: _reviewSignature(snapshot: snapshot),
    issueCommentIds: _relevantIds(comments: snapshot.issueComments),
    issueCommentsTotal: snapshot.issueCommentsTotal,
    reviewSummaryIds: _relevantIds(comments: snapshot.reviewSummaries),
    threadCommentIds: {for (final thread in snapshot.reviewThreads) thread.id: _relevantIds(comments: thread.comments)},
    resolvedThreadIds: {
      for (final thread in snapshot.reviewThreads)
        if (thread.isResolved) thread.id,
    },
    unresolvedThreadCount: snapshot.reviewThreads.where((thread) => !thread.isResolved).length,
    ready: snapshot.labels.any((label) => label.toLowerCase() == agentReadyLabel),
  );

  /// True when [snapshot] holds nothing [baseline] did not: a report against
  /// it would say nothing new. Mergeability GitHub has not computed yet is
  /// not a change.
  bool covers({required PullRequestBaseline baseline, required PullRequestSnapshot snapshot}) {
    final fresh = baselineOf(snapshot: snapshot);
    return baseline ==
        (fresh.mergeable == PullRequestMergeable.unknown ? fresh.copyWith(mergeable: baseline.mergeable) : fresh);
  }

  /// [hasNewCiFailure] against a stored [baseline] instead of the previous
  /// poll, for the first poll after a restart.
  bool hasNewCiFailureSince({required PullRequestBaseline baseline, required PullRequestSnapshot next}) {
    final failing = _failedCheckIds(snapshot: next);
    if (failing.isEmpty) return false;
    if (baseline.headSha != next.headSha) return true;
    return failing.any((id) => !baseline.failedCheckIds.contains(id));
  }

  /// True when something report-worthy changed between consecutive polls.
  bool detectActivity({
    required PullRequestSnapshot previous,
    required PullRequestSnapshot next,
    required PullRequestMergeable? lastDefiniteMergeable,
  }) {
    if (previous.state != next.state) return true;
    // A push starts a fresh review and CI wave even before GitHub registers
    // checks for the new head.
    if (previous.headSha != next.headSha) return true;
    if (_mergeableChanged(lastDefiniteMergeable: lastDefiniteMergeable, next: next)) return true;
    if (_reviewSignature(snapshot: previous) != _reviewSignature(snapshot: next)) return true;
    if (_reviewThreadsChanged(previous: previous.reviewThreads, next: next.reviewThreads)) return true;
    if (previous.issueCommentsTotal != next.issueCommentsTotal ||
        hasAddedRelevantComment(previous: previous.issueComments, next: next.issueComments) ||
        hasAddedRelevantComment(previous: previous.reviewSummaries, next: next.reviewSummaries)) {
      return true;
    }
    // Only a suite conclusion counts: CI starting or progressing stays quiet.
    return ciPhase(snapshot: next) == PullRequestCiPhase.concluded &&
        (ciPhase(snapshot: previous) != PullRequestCiPhase.concluded ||
            _ciConcludedSignature(snapshot: previous) != _ciConcludedSignature(snapshot: next));
  }

  /// Only a settle into a different definite state counts. GitHub recomputes
  /// mergeability whenever the base branch moves, churning through UNKNOWN;
  /// comparing with the last definite value keeps that quiet while still
  /// catching MERGEABLE -> UNKNOWN -> CONFLICTING across two polls.
  bool _mergeableChanged({required PullRequestMergeable? lastDefiniteMergeable, required PullRequestSnapshot next}) {
    if (next.mergeable == PullRequestMergeable.unknown || lastDefiniteMergeable == null) return false;
    return lastDefiniteMergeable != next.mergeable;
  }

  bool _reviewThreadsChanged({
    required List<PullRequestReviewThread> previous,
    required List<PullRequestReviewThread> next,
  }) {
    final before = {for (final thread in previous) thread.id: thread};
    final after = {for (final thread in next) thread.id};
    if (previous.any((thread) => !after.contains(thread.id))) return true;
    return next.any((thread) {
      final earlier = before[thread.id];
      if (earlier == null) return relevantComments(comments: thread.comments).isNotEmpty || !thread.isResolved;
      return earlier.isResolved != thread.isResolved ||
          hasAddedRelevantComment(previous: earlier.comments, next: thread.comments);
    });
  }

  /// A change here is review activity: a new or changed review, or a
  /// reviewer requested or removed.
  String _reviewSignature({required PullRequestSnapshot snapshot}) {
    final states = [
      for (final review in snapshot.reviews)
        "${review.login}=${review.state.name}@${review.submittedAt.toUtc().toIso8601String()}",
    ]..sort();
    final pending = [...snapshot.pendingReviewers]..sort();
    return "${states.join(",")}|${pending.join(",")}";
  }

  Set<String> _relevantIds({required List<PullRequestComment> comments}) => {
    for (final comment in relevantComments(comments: comments)) comment.id,
  };

  Iterable<String> _failedCheckIds({required PullRequestSnapshot snapshot}) =>
      snapshot.checks.where((check) => check.outcome == PullRequestCheckOutcome.failure).map((check) => check.id);

  String _ciConcludedSignature({required PullRequestSnapshot snapshot}) {
    final failed = _failedCheckIds(snapshot: snapshot).toList()..sort();
    return "${snapshot.headSha}:${failed.join(",")}";
  }
}
