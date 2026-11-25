import "package:sesori_tool_interface/sesori_tool_interface.dart" show Log;

import "../api/gh_cli_api.dart";
import "../api/models/gh_rest_pull_request_dto.dart";
import "../models/gh_cli_exception.dart";
import "../models/pull_request_not_open_exception.dart";
import "../models/pull_request_target.dart";
import "models/pull_request_merge_outcome.dart";
import "models/pull_request_snapshot.dart";

/// GitHub identity and the monitor's writes on GitHub: the ready label, the
/// pinned squash merge, and replies.
class PullRequestActionRepository({required final GhCliApi _api}) {
  /// Added after a squash merge the monitor made.
  static const String mergedLabel = "automatically-merged";

  String? _selfLogin;

  /// The login `gh` is signed in as, which tells the user's own comments
  /// from others'. Resolved once per bridge; a failed lookup throws its
  /// `GhCliException` and is retried on the next call.
  Future<String> selfLogin() async => _selfLogin ??= await _api.fetchAuthenticatedLogin();

  /// Adds [agentReadyLabel], creating it in the repository first so it gets
  /// its color and description rather than GitHub's grey default.
  Future<void> addReadyLabel({required PullRequestTarget target}) async {
    await _requireOpen(target: target);
    await _ensureLabel(
      target: target,
      name: agentReadyLabel,
      color: "0e8a16",
      description: "The agent finished its work on this PR",
    );
    await _api.addLabel(target: target, name: agentReadyLabel);
  }

  /// Removes [agentReadyLabel]; false when the PR did not carry it.
  Future<bool> removeReadyLabel({required PullRequestTarget target}) async {
    await _requireOpen(target: target);
    try {
      await _api.removeLabel(target: target, name: agentReadyLabel);
      return true;
    } on GhCliNotFoundException {
      return false;
    }
  }

  /// One squash merge of [headSha] titled [title] with an empty body, then
  /// [mergedLabel]. A call without a usable answer is settled by reading the
  /// PR back once, so a merge that did happen is never retried as unknown.
  Future<PullRequestMergeOutcome> squashMerge({
    required PullRequestTarget target,
    required String headSha,
    required String title,
  }) async {
    final GhMergeResultDto result;
    try {
      result = await _api.squashMerge(target: target, headSha: headSha, title: title);
    } on GhCliException catch (error) {
      return switch (error) {
        GhCliCommandFailedException(httpStatus: 409) => const PullRequestMergeHeadChanged(actualHeadSha: null),
        GhCliCommandFailedException(:final httpStatus?)
            when httpStatus >= 400 && httpStatus < 500 && httpStatus != 408 =>
          PullRequestMergeRejected(reason: error.message, cause: error),
        GhCliNotFoundException() || GhCliUnauthenticatedException() => PullRequestMergeRejected(
          reason: error.message,
          cause: error,
        ),
        _ => await _reconcile(target: target, headSha: headSha, cause: error),
      };
    }
    if (result.merged != true) {
      return PullRequestMergeRejected(reason: result.message ?? "GitHub did not confirm the merge.", cause: null);
    }
    return await _markMerged(target: target);
  }

  /// Posts [body] with [sesoriReplyPrefix], in review thread [threadId] or
  /// as a PR comment, and returns its URL.
  Future<String> reply({required PullRequestTarget target, required String? threadId, required String body}) {
    final text = body.startsWith(sesoriReplyPrefix) ? body : "$sesoriReplyPrefix $body";
    return threadId == null
        ? _api.addComment(target: target, body: text)
        : _api.replyToThread(threadId: threadId, body: text);
  }

  Future<PullRequestMergeOutcome> _reconcile({
    required PullRequestTarget target,
    required String headSha,
    required GhCliException cause,
  }) async {
    final GhRestPullRequestDto observed;
    try {
      observed = await _api.fetchRestPullRequest(target: target);
    } on GhCliException catch (error) {
      return PullRequestMergeOutcomeUnknown(
        detail: "the merge request did not return a usable result ($cause), and the follow-up PR query failed ($error)",
        cause: cause,
      );
    }
    final observedHead = observed.head.sha;
    if (observed.merged && observedHead == headSha) return await _markMerged(target: target);
    if (observed.state == GhRestPullRequestStateDto.open && observedHead != headSha) {
      return PullRequestMergeHeadChanged(actualHeadSha: observedHead);
    }
    final state = observed.merged ? "MERGED" : observed.state.name.toUpperCase();
    return PullRequestMergeOutcomeUnknown(
      detail:
          "the merge request did not return a usable result ($cause); the follow-up PR query observed $state at "
          "head $observedHead, so the accepted head could not be confirmed as merged",
      cause: cause,
    );
  }

  Future<PullRequestMerged> _markMerged({required PullRequestTarget target}) async {
    try {
      await _ensureLabel(
        target: target,
        name: mergedLabel,
        color: "1d76db",
        description: "Merged automatically by Sesori PR Monitor",
      );
      await _api.addLabel(target: target, name: mergedLabel);
      return const PullRequestMerged(labelError: null);
    } on GhCliException catch (error, stackTrace) {
      Log.w("PR monitor: labelling ${target.displayKey} $mergedLabel failed", error, stackTrace);
      return PullRequestMerged(labelError: error);
    }
  }

  /// The label endpoints share the issue namespace, so without this an issue
  /// number, or a merged or closed PR, would be labelled as if it were open.
  Future<void> _requireOpen({required PullRequestTarget target}) async {
    final pullRequest = await _api.fetchRestPullRequest(target: target);
    if (pullRequest.state != GhRestPullRequestStateDto.open) {
      throw PullRequestNotOpenException(merged: pullRequest.merged);
    }
  }

  /// Creating fails when the label exists, which keeps the repository's own
  /// version; a real failure shows on the add that follows.
  Future<void> _ensureLabel({
    required PullRequestTarget target,
    required String name,
    required String color,
    required String description,
  }) async {
    try {
      await _api.createLabel(target: target, name: name, color: color, description: description);
    } on GhCliException {
      // Usually 422 already_exists.
    }
  }
}
