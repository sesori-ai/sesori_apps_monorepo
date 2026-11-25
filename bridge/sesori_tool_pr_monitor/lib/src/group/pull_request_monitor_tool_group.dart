import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../listeners/pull_request_poll_listener.dart";
import "../models/pull_request_target.dart";
import "../repositories/models/pull_request_snapshot.dart";
import "../services/models/pull_request_config_change.dart";
import "../services/models/pull_request_watch_results.dart";
import "../services/pull_request_config_description_builder.dart";
import "../services/pull_request_report_builder.dart";
import "../services/pull_request_watch_service.dart";
import "pull_request_monitor_guide.dart";
import "pull_request_monitor_tool.dart";

/// `watch_pr` and its companions: GitHub PRs Sesori watches for a session,
/// messaging it a report when they change.
class PullRequestMonitorToolGroup({
  required final PullRequestWatchService _watches,
  required final PullRequestPollListener _poller,
  required final PullRequestReportBuilder _reports,
  required final PullRequestConfigDescriptionBuilder _configDescriptions,
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
            requestedAutoMerge: _flag(value: arguments["auto_merge"], field: "auto_merge"),
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
      PullRequestMonitorTool.configurePrMonitor => _configure(
        sessionId: sessionId,
        change: _configChange(arguments: arguments),
      ),
    };
  }

  Future<SesoriToolResult> _configure({required String sessionId, required PullRequestConfigChange change}) => _attempt(
    failure: "Cannot change the PR monitor settings",
    run: () async => switch (await _watches.configure(sessionId: sessionId, change: change)) {
      PullRequestConfigApplied(:final config) => "Saved. ${_configDescriptions.settingsText(config: config)}",
      PullRequestConfigAwaitingApproval(:final config) =>
        "Sent to the user for approval: turning auto-merge on by default needs their Allow. A message tells "
            "this session their answer; end your turn instead of waiting. Until then: "
            "${_configDescriptions.settingsText(config: config)}",
      PullRequestConfigApprovalDropped(:final config) =>
        "Auto-merge by default is unchanged: the request for the user's Allow could not be shown, as the "
            "bridge is stopping or this session is gone. ${_configDescriptions.settingsText(config: config)}",
    },
  );

  /// The `configure_pr_monitor` arguments as one change, or why they are
  /// invalid. Strict-schema providers may send "" for a field left out.
  PullRequestConfigChange _configChange({required Map<String, Object?> arguments}) {
    final autoMerge = switch (arguments["auto_merge"]) {
      null || "" => null,
      "on" => true,
      "off" => false,
      _ => throw const InvalidToolArguments(reason: "auto_merge must be on or off."),
    };
    final repository = switch (_text(value: arguments["repository"], field: "repository")) {
      null || "" => null,
      final input => _repositoryKey(input: input),
    };
    final clear = _flag(value: arguments["clear_repository"], field: "clear_repository") ?? false;
    final autoMergeChange = switch ((autoMerge, repository, clear)) {
      (_, null, true) => throw const InvalidToolArguments(reason: "clear_repository needs repository."),
      (_?, _, true) => throw const InvalidToolArguments(
        reason: "Give either auto_merge or clear_repository, not both.",
      ),
      (null, _?, false) => throw const InvalidToolArguments(reason: "repository needs auto_merge or clear_repository."),
      (null, final repositoryKey?, true) => PullRequestRepositoryAutoMergeCleared(repositoryKey: repositoryKey),
      (final enabled?, final repositoryKey?, false) => PullRequestRepositoryAutoMerge(
        repositoryKey: repositoryKey,
        enabled: enabled,
      ),
      (final enabled?, null, false) => PullRequestGlobalAutoMerge(enabled: enabled),
      (null, null, false) => null,
    };
    return PullRequestConfigChange(
      autoMerge: autoMergeChange,
      quietMinutes: _minutes(value: arguments["quiet_minutes"], field: "quiet_minutes", min: 1, max: 60),
      ciWaitMinutes: _minutes(value: arguments["ci_wait_minutes"], field: "ci_wait_minutes", min: 5, max: 240),
      idleReminderMinutes: switch (arguments["idle_reminder_minutes"]) {
        0 => 0,
        final value => _minutes(value: value, field: "idle_reminder_minutes", min: 5, max: 240),
      },
    );
  }

  String _repositoryKey({required String input}) {
    try {
      return PullRequestTarget.parseRepositoryKey(input: input);
    } on FormatException catch (error) {
      throw InvalidToolArguments(reason: error.message);
    }
  }

  /// A whole number of minutes from [min] to [max], or null when absent.
  int? _minutes({required Object? value, required String field, required int min, required int max}) => switch (value) {
    null || "" => null,
    final int minutes when minutes >= min && minutes <= max => minutes,
    _ => throw InvalidToolArguments(reason: "$field must be a whole number from $min to $max."),
  };

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
    PullRequestMarkedReady(:final mergeAttempt) => [
      'Marked ${target.displayKey} as ready: label "$agentReadyLabel" added.',
      if (mergeAttempt != null) _reports.mergeAttemptText(target: target, attempt: mergeAttempt),
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
    final settings = _configDescriptions.settingsText(config: statuses.config);
    if (statuses.watches.isEmpty) return "This session watches no PRs. $polled\n$settings";
    return [for (final status in statuses.watches) _statusLine(status: status), polled, settings].join("\n");
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
