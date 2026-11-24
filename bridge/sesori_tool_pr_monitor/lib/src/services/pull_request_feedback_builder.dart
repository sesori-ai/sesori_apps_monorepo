import "../models/pull_request_target.dart";
import "../repositories/models/pull_request_snapshot.dart";
import "pull_request_readiness_calculator.dart";

/// Renders on-demand feedback (spec §9): the comment bodies reports omit,
/// limited to the channels automatic readiness still counts as unanswered.
class const PullRequestFeedbackBuilder({required final PullRequestReadinessCalculator _readiness}) {
  // ponytail: a per-comment cap keeps one huge bot dump from flooding the
  // context; raise it if agents miss detail.
  static const int _maxBodyChars = 4000;
  static final RegExp _htmlComment = RegExp(r"<!--[\s\S]*?-->");
  static final RegExp _lineStart = RegExp("^", multiLine: true);

  String build({required PullRequestTarget target, required PullRequestSnapshot snapshot}) {
    final sections = <String>[
      for (final thread in snapshot.reviewThreads)
        if (!_readiness.channelIsAcknowledged(comments: thread.comments)) _threadSection(thread: thread),
    ];
    final unthreaded = [...snapshot.issueComments, ...snapshot.reviewSummaries];
    if (unthreaded.isNotEmpty && !_readiness.channelIsAcknowledged(comments: unthreaded)) {
      sections.add(
        "### PR comments and review summaries (reply without `thread_id`)\n\n${_renderComments(comments: unthreaded)}",
      );
    }

    final key = target.displayKey;
    if (sections.isEmpty) return "No feedback on $key is awaiting a reply.";
    return "Feedback on $key awaiting a reply (${sections.length} channel${sections.length == 1 ? "" : "s"}):\n\n"
        "${sections.join("\n\n")}\n\n"
        'Answer each channel with reply_on_pr(pr: "$key", thread_id: "<thread id>", body: "...") '
        "or omit thread_id for a PR comment; the reply prefix is added for you. A non-actionable bot acknowledgement "
        "needs no reply: use mark_pr_ready instead.";
  }

  String _threadSection({required PullRequestReviewThread thread}) {
    final path = thread.path;
    final line = thread.line;
    final location = path == null ? "" : " on ${line == null ? path : "$path:$line"}";
    final state = thread.isResolved ? "resolved" : "unresolved";
    final botOnly = thread.comments.every(
      (comment) => comment.isBot || comment.origin == PullRequestCommentOrigin.agentReply,
    );
    return "### Thread `${thread.id}`$location ($state${botOnly ? ", bot-only" : ""})\n\n"
        "${_renderComments(comments: thread.comments)}";
  }

  /// The comments at or after the latest agent reply, oldest first: earlier
  /// ones were answered. A same-second tie stays listed because readiness
  /// treats it as unanswered too.
  String _renderComments({required List<PullRequestComment> comments}) {
    DateTime? lastReply;
    for (final comment in comments) {
      if (comment.origin == PullRequestCommentOrigin.agentReply &&
          (lastReply == null || comment.createdAt.isAfter(lastReply))) {
        lastReply = comment.createdAt;
      }
    }
    final unanswered = [
      for (final (index, comment) in comments.indexed)
        if (comment.origin != PullRequestCommentOrigin.agentReply &&
            (lastReply == null || !comment.createdAt.isBefore(lastReply)))
          (index: index, comment: comment),
    ];
    // List.sort is not stable, so ties keep their fetched order.
    unanswered.sort((a, b) {
      final byTime = a.comment.createdAt.compareTo(b.comment.createdAt);
      return byTime != 0 ? byTime : a.index.compareTo(b.index);
    });
    return [for (final item in unanswered) _renderComment(comment: item.comment)].join("\n\n");
  }

  String _renderComment({required PullRequestComment comment}) {
    final raw = comment.body.replaceAll(_htmlComment, "").trim();
    final body = raw.length > _maxBodyChars ? "${raw.substring(0, _maxBodyChars)}\n[truncated]" : raw;
    final kind = comment.isBot
        ? "bot"
        : comment.origin == PullRequestCommentOrigin.local
        ? "local account, unprefixed: a human instruction"
        : "human";
    final quoted = (body.isEmpty ? "(no text)" : body).replaceAll(_lineStart, "> ");
    return "**${comment.author}** ($kind, ${comment.createdAt.toUtc().toIso8601String()}):\n$quoted";
  }
}
