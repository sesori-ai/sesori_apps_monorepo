import "../models/pull_request_target.dart";
import "../repositories/models/pull_request_baseline.dart";
import "../repositories/models/pull_request_snapshot.dart";
import "pull_request_activity_calculator.dart";
import "pull_request_readiness_calculator.dart";

/// Renders the report and idle-reminder texts (spec §5). Reports never carry
/// comment bodies or advice about a review's substance.
class const PullRequestReportBuilder({
  required final PullRequestActivityCalculator _activity,
  required final PullRequestReadinessCalculator _readiness,
}) {
  /// The full report. "New" means absent from [baseline]; a null baseline is
  /// a watch's first report, where every existing comment counts as new.
  /// [forcedHoldMinutes] is set when a CI hold ran out and the report goes
  /// out while CI still runs.
  String buildReport({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
    required PullRequestBaseline? baseline,
    required int? forcedHoldMinutes,
    required bool autoMergeEnabled,
  }) {
    final stateSuffix = switch (snapshot.state) {
      PullRequestState.open => "",
      PullRequestState.merged => " — MERGED",
      PullRequestState.closed => " — CLOSED",
    };
    final newIssue = _newSince(comments: snapshot.issueComments, seenIds: baseline?.issueCommentIds);
    final newReviewSummaries = _newSince(comments: snapshot.reviewSummaries, seenIds: baseline?.reviewSummaryIds);
    return [
      "${_header(target: target, snapshot: snapshot)}$stateSuffix",
      _ciLine(snapshot: snapshot, forcedHoldMinutes: forcedHoldMinutes),
      _mergeableLine(snapshot: snapshot),
      _reviewLine(snapshot: snapshot),
      if (newReviewSummaries.isEmpty)
        "- [comment:review] 0 new relevant review summaries since last flush"
      else
        _reviewSummaryLine(fresh: newReviewSummaries),
      _inlineLine(snapshot: snapshot, baseline: baseline),
      _issueLine(snapshot: snapshot, fresh: newIssue),
      ..._readinessLines(target: target, snapshot: snapshot, autoMergeEnabled: autoMergeEnabled),
      if (snapshot.labels.isNotEmpty) "- Labels: ${snapshot.labels.join(", ")}",
      ?switch (snapshot.state) {
        PullRequestState.open => null,
        PullRequestState.merged => "- Monitor stopped: PR merged",
        PullRequestState.closed => "- Monitor stopped: PR closed",
      },
    ].join("\n");
  }

  /// A short nudge for an open PR with no activity and no report for
  /// [idleMinutes]: current state only, nothing "new since".
  String buildIdleReminder({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
    required int idleMinutes,
    required bool autoMergeEnabled,
  }) {
    final unresolved = snapshot.reviewThreads.where((thread) => !thread.isResolved).length;
    return [
      "${_header(target: target, snapshot: snapshot)} — idle reminder",
      _idleLine(idleMinutes: idleMinutes),
      _ciLine(snapshot: snapshot, forcedHoldMinutes: null),
      _mergeableLine(snapshot: snapshot),
      _reviewLine(snapshot: snapshot),
      "- [comment:inline] ${_countLabel(count: unresolved, singular: "unresolved thread")}",
      ..._readinessLines(target: target, snapshot: snapshot, autoMergeEnabled: autoMergeEnabled),
      if (autoMergeEnabled && _readiness.hasReadyLabel(snapshot: snapshot)) _stuckMergeLine(target: target),
    ].join("\n");
  }

  static const String _autoMergeLine =
      "- Auto-merge: ENABLED — readiness (automatic or mark_pr_ready) makes one squash-merge attempt, as the "
      "user wants; never hold mark_pr_ready back to wait for a human.";

  String _reviewSummaryLine({required List<PullRequestComment> fresh}) =>
      "- [comment:review] ACTION REQUIRED: ${_countLabel(count: fresh.length, singular: "new relevant review summary")} "
      "since last flush (${_authorBreakdown(comments: fresh)}).";

  String _issueLine({required PullRequestSnapshot snapshot, required List<PullRequestComment> fresh}) {
    final freshPart = fresh.isEmpty
        ? "0 new since last flush"
        : "${fresh.length} new relevant since last flush: ${_authorBreakdown(comments: fresh)}";
    return "- [comment:issue] ${snapshot.issueCommentsTotal} total ($freshPart)";
  }

  String _idleLine({required int idleMinutes}) =>
      "- Idle: no PR activity and no report for ${idleMinutes}m. Pick this PR back up now: re-check the "
      "current head's checks, expected reviews, and feedback instead of waiting for another report.";

  String _stuckMergeLine({required PullRequestTarget target}) =>
      "- Required next step: the PR is ready with auto-merge on but is still open, so the merge did not go "
      "through. Find out why (checks, required reviews, branch protection, conflicts), fix what you can and call "
      "${_markReadyCall(target: target)} to retry the merge, or tell the user what blocks it.";

  String _requiredNextStepLine({required PullRequestTarget target}) =>
      "- Required next step: Do more work until the PR is ready, or use ${_markReadyCall(target: target)} if you "
      "believe nothing else is required. Local agent replies count only when they begin with "
      "${_inlineCode(value: sesoriReplyPrefix)}.";

  String _header({required PullRequestTarget target, required PullRequestSnapshot snapshot}) {
    final title = snapshot.title.replaceAll(RegExp(r"\s+"), " ").trim();
    return '[PR Monitor] [${target.displayKey}](${snapshot.url}) — "$title"';
  }

  List<String> _readinessLines({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
    required bool autoMergeEnabled,
  }) {
    final ready = _readiness.hasReadyLabel(snapshot: snapshot);
    final blockers = ready || snapshot.state != PullRequestState.open
        ? const <String>[]
        : _readiness.assess(snapshot: snapshot).blockers;
    return [
      if (ready)
        '- Ready: YES — label "$agentReadyLabel" is present.'
      else
        '- Ready: NO — label "$agentReadyLabel" is absent.',
      if (autoMergeEnabled) _autoMergeLine,
      if (blockers.isNotEmpty) "- Automatic readiness blocked by: ${blockers.join("; ")}.",
      if (!ready && snapshot.state == PullRequestState.open) _requiredNextStepLine(target: target),
    ];
  }

  String _markReadyCall({required PullRequestTarget target}) =>
      _inlineCode(value: 'mark_pr_ready(pr: "${target.displayKey}")');

  String _ciLine({required PullRequestSnapshot snapshot, required int? forcedHoldMinutes}) {
    final total = snapshot.checks.length;
    final failed = [
      for (final check in snapshot.checks)
        if (check.outcome == PullRequestCheckOutcome.failure) check.name,
    ];
    final pending = [
      for (final check in snapshot.checks)
        if (check.outcome == PullRequestCheckOutcome.pending) check.name,
    ];
    switch (_activity.ciPhase(snapshot: snapshot)) {
      case PullRequestCiPhase.none:
        return "- CI: none";
      case PullRequestCiPhase.concluded:
        return failed.isEmpty
            ? "- CI: passing ($total/$total)"
            : "- CI: failing (${failed.length}/$total failed: ${failed.join(", ")})";
      case PullRequestCiPhase.running:
        if (forcedHoldMinutes != null) {
          return "- CI: running for ${forcedHoldMinutes}m+ (in_progress: ${pending.join(", ")})";
        }
        final failedPart = failed.isEmpty ? "" : ", ${failed.length} failed so far: ${failed.join(", ")}";
        return "- CI: running (${total - pending.length}/$total done$failedPart)";
    }
  }

  String _mergeableLine({required PullRequestSnapshot snapshot}) =>
      "- Mergeable: ${snapshot.mergeable.name.toUpperCase()}";

  String _reviewLine({required PullRequestSnapshot snapshot}) {
    final parts = [
      for (final review in snapshot.reviews)
        "${review.login} ${switch (review.state) {
          PullRequestReviewState.approved => "✓ approved",
          PullRequestReviewState.changesRequested => "✗ changes_requested",
          PullRequestReviewState.commented => "✦ commented",
          PullRequestReviewState.dismissed => "⊘ dismissed",
          PullRequestReviewState.pending => "pending",
          PullRequestReviewState.unknown => "unknown",
        }}",
      for (final login in snapshot.pendingReviewers) "$login ⏳ pending",
    ];
    return "- Reviews: ${parts.isEmpty ? "none" : parts.join(" · ")}";
  }

  String _inlineLine({required PullRequestSnapshot snapshot, required PullRequestBaseline? baseline}) {
    final unresolved = snapshot.reviewThreads.where((thread) => !thread.isResolved).length;
    final changed = [
      for (final thread in snapshot.reviewThreads)
        if (_newSince(
              comments: thread.comments,
              seenIds: baseline == null ? null : baseline.threadCommentIds[thread.id] ?? const {},
            )
            case final comments when comments.isNotEmpty)
          (thread: thread, comments: comments),
    ];
    if (changed.isEmpty) {
      return "- [comment:inline] ${_countLabel(count: unresolved, singular: "unresolved thread")}; "
          "0 threads received new relevant comments since last flush";
    }

    final fresh = [for (final item in changed) ...item.comments];
    final unresolvedNotice = switch (baseline?.unresolvedThreadCount) {
      null => "Inspect every changed thread regardless of the current unresolved-thread count ($unresolved).",
      final previous when previous == unresolved =>
        "The unresolved-thread count is unchanged at $unresolved; inspect every changed thread anyway.",
      final previous =>
        "The unresolved-thread count changed from $previous to $unresolved; inspect every changed thread.",
    };
    final changedUnresolved = changed.where((item) => !item.thread.isResolved).length;
    final changedResolved = changed.length - changedUnresolved;
    final states = [
      if (changedUnresolved > 0) "$changedUnresolved currently unresolved",
      if (changedResolved > 0) "$changedResolved currently resolved",
    ];
    final changedThreads = [
      for (final item in changed)
        "${_threadLocator(thread: item.thread)} (${item.thread.isResolved ? "resolved" : "unresolved"}; ${_authorBreakdown(comments: item.comments)})",
    ].join("; ");
    final localNotice = fresh.any((comment) => comment.origin == PullRequestCommentOrigin.local)
        ? " A listed ${_inlineCode(value: "[local account, unprefixed]")} entry is a new human comment, not an "
              "earlier agent reply."
        : "";
    final pendingNotice = fresh.any(_isLocalPending)
        ? " Pending-review comments may be absent from REST pull-comment results; inspect the listed thread through "
              "GraphQL before marking ready."
        : "";
    return "- [comment:inline] ACTION REQUIRED: ${_countLabel(count: changed.length, singular: "thread")} received "
        "${_countLabel(count: fresh.length, singular: "new relevant comment")} since last flush "
        "(${states.join(", ")}; ${_authorBreakdown(comments: fresh)}). $unresolvedNotice "
        "Changed threads: $changedThreads.$localNotice$pendingNotice";
  }

  /// The relevant comments whose id is not in [seenIds]; all of them when
  /// [seenIds] is null.
  List<PullRequestComment> _newSince({
    required List<PullRequestComment> comments,
    required Set<String>? seenIds,
  }) => _activity.relevantComments(
    comments: seenIds == null ? comments : comments.where((comment) => !seenIds.contains(comment.id)).toList(),
  );

  static bool _isLocalPending(PullRequestComment comment) =>
      comment.origin == PullRequestCommentOrigin.local && comment.reviewState == PullRequestReviewState.pending;

  /// `N author` entries, most frequent first, in first-seen order on ties.
  String _authorBreakdown({required List<PullRequestComment> comments}) {
    final counts = <String, int>{};
    for (final comment in comments) {
      final account = comment.isBot ? "${comment.author}[bot]" : comment.author;
      final qualifiers = [
        if (comment.origin == PullRequestCommentOrigin.local) "local account, unprefixed",
        if (comment.reviewState == PullRequestReviewState.pending) "pending review",
      ];
      final name = qualifiers.isEmpty ? account : "$account [${qualifiers.join("; ")}]";
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    // List.sort is not stable, so ties fall back to first-seen order.
    final order = List.generate(entries.length, (index) => index)
      ..sort((a, b) {
        final byCount = entries[b].value.compareTo(entries[a].value);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return [for (final index in order) "${entries[index].value} ${entries[index].key}"].join(", ");
  }

  String _countLabel({required int count, required String singular}) => "$count $singular${count == 1 ? "" : "s"}";

  /// A Markdown code span whose backtick fence never occurs in [value].
  String _inlineCode({required String value}) {
    var length = 1;
    while (value.contains("`" * length)) {
      length++;
    }
    final fence = "`" * length;
    return "$fence$value$fence";
  }

  String _threadLocator({required PullRequestReviewThread thread}) {
    final threadId = "thread ${_inlineCode(value: thread.id)}";
    final path = thread.path;
    if (path == null) return threadId;
    final line = thread.line;
    return "${_inlineCode(value: line == null ? path : "$path:$line")} [$threadId]";
  }
}
