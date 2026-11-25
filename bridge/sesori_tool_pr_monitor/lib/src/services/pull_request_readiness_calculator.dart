import "package:meta/meta.dart";

import "../repositories/models/pull_request_ci_phase.dart";
import "../repositories/models/pull_request_snapshot.dart";
import "pull_request_activity_calculator.dart";

@immutable
class const PullRequestReadinessAssessment({
  /// Why the PR may not be marked ready automatically, as report text.
  required final List<String> blockers,
  required final int awaitingThreadReplies,
  required final bool awaitingUnthreadedReply,
}) {
  bool get eligible => blockers.isEmpty;
}

/// When a PR counts as ready, and when a ready PR stops being ready
/// (spec §3 "Handled" and §6).
class const PullRequestReadinessCalculator({required final PullRequestActivityCalculator _activity}) {
  /// A channel is acknowledged when it is non-empty and every comment at its
  /// latest timestamp is an agent reply. GitHub timestamps collide at
  /// one-second precision, so a mixed tie stays unacknowledged until a later
  /// reply removes the ambiguity.
  bool channelIsAcknowledged({required List<PullRequestComment> comments}) =>
      comments.isNotEmpty &&
      _latestComments(comments: comments).every((comment) => comment.origin == PullRequestCommentOrigin.agentReply);

  bool ciIsReady({required PullRequestSnapshot snapshot}) => switch (_activity.ciPhase(snapshot: snapshot)) {
    PullRequestCiPhase.none => true,
    PullRequestCiPhase.running => false,
    PullRequestCiPhase.concluded => snapshot.checks.every((check) => check.outcome == PullRequestCheckOutcome.success),
  };

  PullRequestReadinessAssessment assess({required PullRequestSnapshot snapshot}) {
    final blockers = <String>[
      if (snapshot.state != PullRequestState.open) "PR is ${snapshot.state.name}",
      if (!ciIsReady(snapshot: snapshot))
        _activity.ciPhase(snapshot: snapshot) == PullRequestCiPhase.running ? "CI is running" : "CI is failing",
      ?switch (snapshot.mergeable) {
        PullRequestMergeable.mergeable => null,
        PullRequestMergeable.conflicting => "the PR has a merge conflict",
        PullRequestMergeable.unknown => "mergeability is still unknown",
      },
    ];

    final awaitingThreadReplies = snapshot.reviewThreads
        .where((thread) => !channelIsAcknowledged(comments: thread.comments))
        .length;
    if (awaitingThreadReplies > 0) {
      blockers.add(
        "$awaitingThreadReplies review ${awaitingThreadReplies == 1 ? "thread awaits" : "threads await"} "
        "a prefixed reply from the local GitHub account",
      );
    }

    final unthreaded = _unthreaded(snapshot: snapshot);
    final awaitingUnthreadedReply = unthreaded.isNotEmpty && !channelIsAcknowledged(comments: unthreaded);
    if (awaitingUnthreadedReply) {
      blockers.add("issue or review-summary feedback awaits a prefixed reply from the local GitHub account");
    }

    return PullRequestReadinessAssessment(
      blockers: blockers,
      awaitingThreadReplies: awaitingThreadReplies,
      awaitingUnthreadedReply: awaitingUnthreadedReply,
    );
  }

  /// GitHub label names are case-insensitive.
  bool hasReadyLabel({required PullRequestSnapshot snapshot}) =>
      snapshot.labels.any((label) => label.toLowerCase() == agentReadyLabel);

  /// True when a channel that was acknowledged no longer is. A present empty
  /// thread is unacknowledged, so its appearance, or the deletion of its last
  /// prefixed reply, counts.
  bool hasAcknowledgementRegression({required PullRequestSnapshot previous, required PullRequestSnapshot next}) {
    final unthreaded = _unthreaded(snapshot: next);
    if (unthreaded.isNotEmpty &&
        channelIsAcknowledged(comments: _unthreaded(snapshot: previous)) &&
        !channelIsAcknowledged(comments: unthreaded)) {
      return true;
    }
    final before = {for (final thread in previous.reviewThreads) thread.id: thread.comments};
    return next.reviewThreads.any((thread) {
      if (channelIsAcknowledged(comments: thread.comments)) return false;
      final earlier = before[thread.id];
      return earlier == null || channelIsAcknowledged(comments: earlier);
    });
  }

  /// A present ready label accepts the snapshot it was applied at. Only later
  /// negative activity withdraws it, so a manual mark overrides any current
  /// state without being undone on the next poll. Resolution, approvals,
  /// transient UNKNOWN, merge and close never withdraw it.
  bool hasReadinessInvalidation({
    required PullRequestSnapshot previous,
    required PullRequestSnapshot next,
    required PullRequestMergeable? lastDefiniteMergeable,
  }) {
    if (next.state != PullRequestState.open) return false;
    return previous.headSha != next.headSha ||
        _activity.hasNewMergeConflict(lastDefiniteMergeable: lastDefiniteMergeable, next: next) ||
        (ciIsReady(snapshot: previous) && !ciIsReady(snapshot: next)) ||
        _activity.hasNewCiFailure(previous: previous, next: next) ||
        hasAcknowledgementRegression(previous: previous, next: next) ||
        _activity.reviewThreadsReceivedNewComments(previous: previous.reviewThreads, next: next.reviewThreads) ||
        _activity.hasAddedRelevantComment(previous: previous.issueComments, next: next.issueComments) ||
        _activity.hasAddedRelevantComment(previous: previous.reviewSummaries, next: next.reviewSummaries);
  }

  List<PullRequestComment> _unthreaded({required PullRequestSnapshot snapshot}) => [
    ...snapshot.issueComments,
    ...snapshot.reviewSummaries,
  ];

  List<PullRequestComment> _latestComments({required List<PullRequestComment> comments}) {
    final latestAt = comments.map((comment) => comment.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    return comments.where((comment) => comment.createdAt.isAtSameMomentAs(latestAt)).toList();
  }
}
