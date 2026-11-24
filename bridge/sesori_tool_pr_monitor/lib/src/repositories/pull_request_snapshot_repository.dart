import "../api/gh_cli_api.dart";
import "../api/models/gh_pull_request_dto.dart";
import "../models/pull_request_target.dart";
import "models/pull_request_snapshot.dart";

enum PullRequestPaginationProblem() {
  invalidCursor,
  connectionVanished,
}

/// GitHub's pages for one connection did not chain up. Retryable, like any
/// poll failure that is not a missing PR.
final class const PullRequestPaginationException({
  required final String connection,
  required final PullRequestPaginationProblem problem,
}) implements Exception {
  String get message => switch (problem) {
    PullRequestPaginationProblem.invalidCursor => "GitHub returned an invalid $connection pagination cursor",
    PullRequestPaginationProblem.connectionVanished => "GitHub data changed while fetching $connection",
  };

  @override
  String toString() => message;
}

/// Fetches a pull request through [GhCliApi], following every overflowing
/// connection, and normalizes it into a [PullRequestSnapshot].
///
/// Checks, latest reviews, review threads and labels are paginated. Issue
/// comments and each thread's comments are the latest 100, and review requests
/// the first 50, as in the plugin this ports.
class PullRequestSnapshotRepository({required final GhCliApi _api}) {
  /// Throws a `GhCliException` from the API (`GhCliNotFoundException` when the
  /// PR is gone) or a [PullRequestPaginationException].
  Future<PullRequestSnapshot> fetchSnapshot({
    required PullRequestTarget target,
    required String selfLogin,
  }) async {
    final pullRequest = await _api.fetchPullRequest(target: target);
    final firstCommit = pullRequest.commits.nodes.firstOrNull;
    final firstContexts = firstCommit?.commit.statusCheckRollup?.contexts;
    final contexts = firstContexts == null
        ? const <GhCheckContextDto>[]
        : await _collect(
            connection: "check-context",
            nodes: firstContexts.nodes,
            pageInfo: firstContexts.pageInfo,
            fetchPage: (cursor) async {
              final page = await _api.fetchCheckContextsPage(
                target: target,
                headSha: pullRequest.headRefOid,
                cursor: cursor,
              );
              return page == null ? null : (nodes: page.nodes, pageInfo: page.pageInfo);
            },
          );
    final reviews = await _collect(
      connection: "latest-review",
      nodes: pullRequest.latestReviews.nodes,
      pageInfo: pullRequest.latestReviews.pageInfo,
      fetchPage: (cursor) async {
        final page = await _api.fetchLatestReviewsPage(target: target, cursor: cursor);
        return (nodes: page.nodes, pageInfo: page.pageInfo);
      },
    );
    final threads = await _collect(
      connection: "review-thread",
      nodes: pullRequest.reviewThreads.nodes,
      pageInfo: pullRequest.reviewThreads.pageInfo,
      fetchPage: (cursor) async {
        final page = await _api.fetchReviewThreadsPage(target: target, cursor: cursor);
        return (nodes: page.nodes, pageInfo: page.pageInfo);
      },
    );
    final labels = await _collect(
      connection: "label",
      nodes: pullRequest.labels.nodes,
      pageInfo: pullRequest.labels.pageInfo,
      fetchPage: (cursor) async {
        final page = await _api.fetchLabelsPage(target: target, cursor: cursor);
        return (nodes: page.nodes, pageInfo: page.pageInfo);
      },
    );
    return _normalize(
      pullRequest: pullRequest,
      contexts: contexts,
      reviews: reviews,
      threads: threads,
      labels: labels,
      selfLogin: selfLogin,
    );
  }

  /// Follows [pageInfo] until GitHub reports no further page. A missing or
  /// repeated cursor, or a page whose connection is gone, fails the poll.
  Future<List<N>> _collect<N>({
    required String connection,
    required List<N> nodes,
    required GhPageInfoDto pageInfo,
    required Future<({List<N> nodes, GhPageInfoDto pageInfo})?> Function(String cursor) fetchPage,
  }) async {
    final collected = [...nodes];
    final seenCursors = <String>{};
    var current = pageInfo;
    while (current.hasNextPage) {
      final cursor = current.endCursor;
      if (cursor == null || !seenCursors.add(cursor)) {
        throw PullRequestPaginationException(
          connection: connection,
          problem: PullRequestPaginationProblem.invalidCursor,
        );
      }
      final page = await fetchPage(cursor);
      if (page == null) {
        throw PullRequestPaginationException(
          connection: connection,
          problem: PullRequestPaginationProblem.connectionVanished,
        );
      }
      collected.addAll(page.nodes);
      current = page.pageInfo;
    }
    return collected;
  }

  PullRequestSnapshot _normalize({
    required GhPullRequestDto pullRequest,
    required List<GhCheckContextDto> contexts,
    required List<GhReviewDto> reviews,
    required List<GhReviewThreadDto> threads,
    required List<GhLabelDto> labels,
    required String selfLogin,
  }) {
    final commentMapper = _PullRequestCommentMapper(selfLogin: selfLogin);
    // GitHub sets submittedAt on every submitted review, so a review without
    // one is still pending and is left out with the PENDING ones.
    final submittedReviews = [
      for (final review in reviews)
        if ((review.author, review.submittedAt) case (final GhActorDto author, final DateTime submittedAt)
            when review.state != GhReviewStateDto.pending)
          (review: review, author: author, submittedAt: submittedAt),
    ];
    final issueComments = [
      for (final comment in pullRequest.comments.nodes) commentMapper.mapComment(comment: comment),
    ];
    final agentReplyCount = issueComments
        .where((comment) => comment.origin == PullRequestCommentOrigin.agentReply)
        .length;
    final issueCommentsTotal = pullRequest.comments.totalCount - agentReplyCount;

    return PullRequestSnapshot(
      title: pullRequest.title,
      url: pullRequest.url,
      state: switch (pullRequest.state) {
        GhPullRequestStateDto.open => PullRequestState.open,
        GhPullRequestStateDto.merged => PullRequestState.merged,
        GhPullRequestStateDto.closed => PullRequestState.closed,
      },
      mergeable: switch (pullRequest.mergeable) {
        GhMergeableStateDto.mergeable => PullRequestMergeable.mergeable,
        GhMergeableStateDto.conflicting => PullRequestMergeable.conflicting,
        GhMergeableStateDto.unknown => PullRequestMergeable.unknown,
      },
      headSha: pullRequest.headRefOid,
      checks: [
        for (final context in contexts)
          if (_check(context: context) case final PullRequestCheck check) check,
      ],
      reviews: [
        for (final (:review, :author, :submittedAt) in submittedReviews)
          PullRequestReview(
            login: author.login,
            state: _reviewState(state: review.state),
            submittedAt: submittedAt,
          ),
      ],
      reviewSummaries: [
        for (final (:review, :author, :submittedAt) in submittedReviews)
          if (review.body.trim().isNotEmpty ||
              (review.state == GhReviewStateDto.changesRequested && review.comments.totalCount == 0))
            commentMapper.map(
              id: review.id,
              author: author,
              body: review.body,
              createdAt: submittedAt,
              reviewState: null,
            ),
      ],
      pendingReviewers: [
        for (final request in pullRequest.reviewRequests.nodes)
          if (switch (request.requestedReviewer) {
                GhRequestedUserDto(:final login) || GhRequestedBotDto(:final login) => login,
                GhRequestedTeamDto(:final slug) => slug,
                GhUnknownRequestedReviewerDto() || null => null,
              }
              case final String name)
            name,
      ],
      reviewThreads: [
        for (final thread in threads)
          PullRequestReviewThread(
            id: thread.id,
            isResolved: thread.isResolved,
            path: thread.path,
            line: thread.line ?? thread.originalLine,
            comments: [for (final comment in thread.comments.nodes) commentMapper.mapComment(comment: comment)],
          ),
      ],
      issueCommentsTotal: issueCommentsTotal < 0 ? 0 : issueCommentsTotal,
      issueComments: issueComments,
      labels: [for (final label in labels) label.name],
    );
  }

  PullRequestCheck? _check({required GhCheckContextDto context}) => switch (context) {
    GhCheckRunDto(:final id, :final name, :final status, :final conclusion) => PullRequestCheck(
      id: id,
      name: name,
      outcome: switch (status) {
        GhCheckStatusDto.completed => switch (conclusion) {
          GhCheckConclusionDto.success ||
          GhCheckConclusionDto.neutral ||
          GhCheckConclusionDto.skipped => PullRequestCheckOutcome.success,
          GhCheckConclusionDto.failure ||
          GhCheckConclusionDto.cancelled ||
          GhCheckConclusionDto.timedOut ||
          GhCheckConclusionDto.actionRequired ||
          GhCheckConclusionDto.startupFailure ||
          GhCheckConclusionDto.stale ||
          GhCheckConclusionDto.unknown ||
          null => PullRequestCheckOutcome.failure,
        },
        GhCheckStatusDto.requested ||
        GhCheckStatusDto.queued ||
        GhCheckStatusDto.inProgress ||
        GhCheckStatusDto.waiting ||
        GhCheckStatusDto.pending ||
        GhCheckStatusDto.unknown => PullRequestCheckOutcome.pending,
      },
    ),
    GhStatusContextDto(:final context, :final state, :final createdAt) => PullRequestCheck(
      id: "status:$context:${createdAt.toUtc().toIso8601String()}",
      name: context,
      outcome: switch (state) {
        GhStatusStateDto.success => PullRequestCheckOutcome.success,
        GhStatusStateDto.pending || GhStatusStateDto.expected => PullRequestCheckOutcome.pending,
        GhStatusStateDto.error ||
        GhStatusStateDto.failure ||
        GhStatusStateDto.unknown => PullRequestCheckOutcome.failure,
      },
    ),
    GhUnknownCheckContextDto() => null,
  };
}

PullRequestReviewState _reviewState({required GhReviewStateDto state}) => switch (state) {
  GhReviewStateDto.pending => PullRequestReviewState.pending,
  GhReviewStateDto.commented => PullRequestReviewState.commented,
  GhReviewStateDto.approved => PullRequestReviewState.approved,
  GhReviewStateDto.changesRequested => PullRequestReviewState.changesRequested,
  GhReviewStateDto.dismissed => PullRequestReviewState.dismissed,
  GhReviewStateDto.unknown => PullRequestReviewState.unknown,
};

class _PullRequestCommentMapper({required final String _selfLogin}) {
  static const String _ghostLogin = "ghost";

  PullRequestComment mapComment({required GhCommentDto comment}) => map(
    id: comment.id,
    author: comment.author,
    body: comment.body,
    createdAt: comment.createdAt,
    reviewState: switch (comment.pullRequestReview) {
      GhCommentReviewDto(:final state) => _reviewState(state: state),
      null => null,
    },
  );

  PullRequestComment map({
    required String id,
    required GhActorDto? author,
    required String body,
    required DateTime createdAt,
    required PullRequestReviewState? reviewState,
  }) {
    final login = author?.login ?? _ghostLogin;
    final isLocal = login.toLowerCase() == _selfLogin.toLowerCase();
    return PullRequestComment(
      id: id,
      author: login,
      isBot: author?.kind == GhActorKindDto.bot,
      createdAt: createdAt,
      origin: switch ((isLocal, body.startsWith(sesoriReplyPrefix))) {
        (false, _) => PullRequestCommentOrigin.other,
        (true, false) => PullRequestCommentOrigin.local,
        (true, true) => PullRequestCommentOrigin.agentReply,
      },
      reviewState: reviewState,
    );
  }
}
