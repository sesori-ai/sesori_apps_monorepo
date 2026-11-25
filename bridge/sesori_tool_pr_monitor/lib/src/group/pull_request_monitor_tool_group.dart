import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../listeners/pull_request_poll_listener.dart";
import "../models/pull_request_target.dart";
import "../repositories/models/pull_request_snapshot.dart";
import "../services/models/pull_request_watch_results.dart";
import "../services/pull_request_watch_service.dart";
import "pull_request_monitor_guide.dart";
import "pull_request_monitor_tool.dart";

/// `watch_pr` and its companions: GitHub PRs Sesori watches for a session,
/// messaging it a report when they change.
class PullRequestMonitorToolGroup({
  required final PullRequestWatchService _watches,
  required final PullRequestPollListener _poller,
}) implements SesoriToolGroup {
  static const SesoriToolGroupId groupId = SesoriToolGroupId("pr_monitor");

  static const String _callerGoneText = "This session is no longer known to Sesori.";

  @override
  SesoriToolGroupId get id => groupId;

  @override
  String get title => "PR monitor";

  @override
  String get summary => "Agents can watch GitHub pull requests and hear about CI, reviews and comments, through gh.";

  @override
  String get instructions =>
      "watch_pr has Sesori watch a GitHub pull request and message this session a [PR Monitor] report when its CI, "
      "reviews, comments or state change; call it right after you open a PR, then end your turn instead of polling.";

  @override
  List<SesoriToolDefinition> get tools => [for (final tool in PullRequestMonitorTool.values) tool.definition];

  @override
  SesoriToolGuide get guide => pullRequestMonitorGuide;

  @override
  Future<void> start() async {
    await _watches.resume();
    _poller.start();
  }

  @override
  Future<void> dispose() => _poller.dispose();

  @override
  Future<SesoriToolResult> call({
    required String tool,
    required SesoriToolCaller caller,
    required Map<String, Object?> arguments,
  }) async {
    final sessionId = await _watches.watchSessionOf(caller: caller);
    if (sessionId == null) return const SesoriToolFailure(text: _callerGoneText);
    return await switch (PullRequestMonitorTool.values.firstWhere((candidate) => candidate.wireName == tool)) {
      PullRequestMonitorTool.watchPr => _withTarget(
        arguments: arguments,
        run: (target) async => _watchResult(
          target: target,
          result: await _watches.watch(
            sessionId: sessionId,
            target: target,
            autoMerge: _flag(value: arguments["auto_merge"], field: "auto_merge") ?? false,
          ),
        ),
      ),
      PullRequestMonitorTool.unwatchPr => _withTarget(
        arguments: arguments,
        run: (target) async => SesoriToolSuccess(
          text: await _watches.unwatch(sessionId: sessionId, target: target)
              ? "Stopped watching ${target.displayKey}."
              : "This session is not watching ${target.displayKey}.",
        ),
      ),
      PullRequestMonitorTool.prWatchStatus => Future.value(
        SesoriToolSuccess(
          text: _statusText(statuses: _watches.statusOf(sessionId: sessionId)),
        ),
      ),
      PullRequestMonitorTool.getPrReport => _withTarget(
        arguments: arguments,
        run: (target) async => _reportResult(
          target: target,
          result: await _watches.report(sessionId: sessionId, target: target),
        ),
      ),
      PullRequestMonitorTool.getPrFeedback => _withTarget(
        arguments: arguments,
        run: (target) => _attempt(
          failure: "Cannot fetch feedback for ${target.displayKey}",
          run: () async => await _watches.feedback(target: target),
        ),
      ),
      PullRequestMonitorTool.replyOnPr => _withTarget(
        arguments: arguments,
        run: (target) {
          final body = requiredToolText(
            value: _text(value: arguments["body"], field: "body") ?? "",
            field: "body",
          );
          final threadId = optionalToolText(
            value: _text(value: arguments["thread_id"], field: "thread_id"),
          );
          return _attempt(
            failure: "Cannot reply on ${target.displayKey}",
            run: () async {
              final url = await _watches.reply(target: target, threadId: threadId, body: body);
              return threadId == null
                  ? "Posted a PR comment on ${target.displayKey}: $url"
                  : "Replied on thread $threadId: $url";
            },
          );
        },
      ),
      PullRequestMonitorTool.markPrReady => _withTarget(
        arguments: arguments,
        run: (target) => _attempt(
          failure: "Cannot mark ${target.displayKey} as ready",
          run: () async => _readyText(
            target: target,
            change: await _watches.setReady(sessionId: sessionId, target: target, ready: true),
          ),
        ),
      ),
      PullRequestMonitorTool.unmarkPrReady => _withTarget(
        arguments: arguments,
        run: (target) => _attempt(
          failure: "Cannot withdraw the ready label from ${target.displayKey}",
          run: () async => _readyText(
            target: target,
            change: await _watches.setReady(sessionId: sessionId, target: target, ready: false),
          ),
        ),
      ),
      PullRequestMonitorTool.setPrAutoMerge => _withTarget(
        arguments: arguments,
        run: (target) {
          final enabled = _flag(value: arguments["enabled"], field: "enabled");
          if (enabled == null) throw const InvalidToolArguments(reason: "enabled is required.");
          return _attempt(
            failure: "Cannot change auto-merge for ${target.displayKey}",
            run: () async => _autoMergeText(
              target: target,
              enabled: enabled,
              result: await _watches.setAutoMerge(sessionId: sessionId, target: target, enabled: enabled),
            ),
          );
        },
      ),
    };
  }

  /// [run]'s text, or a failure saying why: every exception on these paths
  /// (`gh`, pagination, a PR that is not open) has actionable text.
  Future<SesoriToolResult> _attempt({required String failure, required Future<String> Function() run}) async {
    try {
      return SesoriToolSuccess(text: await run());
    } on Exception catch (error, stackTrace) {
      Log.w("PR monitor: $failure", error, stackTrace);
      return SesoriToolFailure(text: "$failure: $error");
    }
  }

  /// A boolean argument, or null when absent; strict-schema providers may
  /// send "" for it.
  bool? _flag({required Object? value, required String field}) => switch (value) {
    null || "" => null,
    final bool flag => flag,
    _ => throw InvalidToolArguments(reason: "$field must be true or false."),
  };

  String? _text({required Object? value, required String field}) => switch (value) {
    null => null,
    final String text => text,
    _ => throw InvalidToolArguments(reason: "$field must be a string."),
  };

  String _readyText({required PullRequestTarget target, required PullRequestReadyChange change}) => switch (change) {
    PullRequestMarkedReady(:final autoMergeNotice) => [
      'Marked ${target.displayKey} as ready: label "$agentReadyLabel" added.',
      ?autoMergeNotice,
    ].join(" "),
    PullRequestUnmarkedReady(wasCarried: true) =>
      'Removed the "$agentReadyLabel" label from ${target.displayKey}: it is no longer marked ready.',
    PullRequestUnmarkedReady(wasCarried: false) =>
      '${target.displayKey} did not carry the "$agentReadyLabel" label; nothing to remove.',
  };

  String _autoMergeText({
    required PullRequestTarget target,
    required bool enabled,
    required PullRequestAutoMergeResult result,
  }) {
    final key = target.displayKey;
    return switch (result) {
      PullRequestAutoMergeNotWatched() when enabled =>
        "This session is not watching $key. To watch it with auto-merge on, call watch_pr with auto_merge: true.",
      PullRequestAutoMergeNotWatched() => "This session is not watching $key; nothing to change.",
      PullRequestAutoMergeUnchanged(enabled: true) => "Auto-merge is already on for $key in this session.",
      PullRequestAutoMergeUnchanged(enabled: false) => "Auto-merge is already off for $key in this session.",
      PullRequestAutoMergeSet(enabled: true, :final readyLabelRemoved) => [
        "Auto-merge enabled for $key: $_autoMergeGuidance",
        if (readyLabelRemoved) _readyLabelRemovedText,
      ].join(" "),
      PullRequestAutoMergeSet(enabled: false, effective: true) =>
        "Auto-merge disabled for $key in this session; it stays on because another session watching the PR has "
            "it on.",
      PullRequestAutoMergeSet(enabled: false, effective: false) =>
        "Auto-merge disabled for $key: marking it ready hands it to a human reviewer.",
    };
  }

  static const String _autoMergeGuidance =
      "the user chose to have this PR merged without waiting for human review. Marking it ready, automatically or "
      "with mark_pr_ready, is the merge approval: Sesori makes one squash-merge attempt for the accepted head, "
      "titled with only the PR title. When nothing is left to do and the label is absent, call mark_pr_ready; never "
      "hold it back to wait for a human.";

  static const String _readyLabelRemovedText =
      'The "$agentReadyLabel" label it carried was removed: that handoff was made without auto-merge, so assess the '
      "PR again before marking it ready.";

  /// Runs [run] on the `pr` argument, or answers why it is not a PR.
  Future<SesoriToolResult> _withTarget({
    required Map<String, Object?> arguments,
    required Future<SesoriToolResult> Function(PullRequestTarget target) run,
  }) {
    final pr = arguments["pr"];
    final PullRequestTarget target;
    try {
      target = PullRequestTarget.parse(
        input: requiredToolText(value: pr is String ? pr : "", field: "pr"),
      );
    } on FormatException catch (error) {
      return Future.value(SesoriToolFailure(text: error.message));
    }
    return run(target);
  }

  SesoriToolResult _watchResult({required PullRequestTarget target, required PullRequestWatchStart result}) =>
      switch (result) {
        PullRequestWatchStarted(:final title, :final report, :final autoMerge, :final readyLabelRemoved) =>
          SesoriToolSuccess(
            text:
                'Started watching ${target.displayKey} — "$title". Reports arrive in this session as messages; end '
                "your turn instead of polling.${autoMerge ? " Auto-merge enabled: $_autoMergeGuidance" : ""}"
                "${readyLabelRemoved ? " $_readyLabelRemovedText" : ""}\n\n$report",
          ),
        PullRequestAlreadyWatched(:final status) => SesoriToolSuccess(
          text: "Already watching ${target.displayKey} in this session.\n${_statusLine(status: status)}",
        ),
        PullRequestIdentityFailed(:final error) => SesoriToolFailure(
          text: "Cannot watch ${target.displayKey}: resolving the gh account failed. ${error.message}",
        ),
        PullRequestFetchFailed(:final error) => SesoriToolFailure(text: "Cannot watch ${target.displayKey}: $error"),
        PullRequestReadyResetFailed(:final error) => SesoriToolFailure(
          text:
              'Cannot watch ${target.displayKey} with auto-merge: removing the "$agentReadyLabel" label it carries '
              "failed: $error",
        ),
        PullRequestAlreadyEnded(:final state) => SesoriToolFailure(
          text:
              "Cannot watch ${target.displayKey}: it is already "
              "${state == PullRequestState.merged ? "merged" : "closed"}.",
        ),
      };

  SesoriToolResult _reportResult({required PullRequestTarget target, required PullRequestReportResult result}) =>
      switch (result) {
        PullRequestReportFresh(:final report) => SesoriToolSuccess(text: report),
        PullRequestReportStale(:final report, :final error) => SesoriToolSuccess(
          text: "$report\n(note: refresh failed — $error; data is from the previous poll; baseline NOT reset)",
        ),
        PullRequestReportUnavailable(:final error) => SesoriToolFailure(
          text: "Cannot fetch ${target.displayKey}: $error",
        ),
        PullRequestNotWatched() => SesoriToolFailure(
          text: "This session is not watching ${target.displayKey}; call watch_pr first.",
        ),
      };

  String _statusText({required PullRequestWatchStatuses statuses}) {
    final polled =
        "This computer polls ${statuses.watchedPullRequests} watched PR${statuses.watchedPullRequests == 1 ? "" : "s"} "
        "once a minute.";
    if (statuses.watches.isEmpty) return "This session watches no PRs. $polled";
    return [for (final status in statuses.watches) _statusLine(status: status), polled].join("\n");
  }

  /// `owner/repo#N — watching, quiet, last report 3m ago, ready: no`.
  String _statusLine({required PullRequestWatchStatus status}) => [
    "${status.target.displayKey} — ${status.ciHold ? "ci-hold" : "watching"}",
    if (status.activityBuffered) "activity buffered" else "quiet",
    "last report ${status.sinceLastReport.inMinutes}m ago",
    if (status.consecutiveFailures > 0) "${status.consecutiveFailures} consecutive poll failures",
    ?switch (status.ready) {
      null => null,
      true => "ready: yes",
      false => "ready: no",
    },
    if (status.autoMerge) "auto-merge: squash",
  ].join(", ");
}
