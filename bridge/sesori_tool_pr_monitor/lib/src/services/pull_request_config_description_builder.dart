import "../models/pull_request_target.dart";
import "../repositories/models/pull_request_monitor_config.dart";
import "models/pull_request_approval_answer.dart";
import "models/pull_request_config_change.dart";

/// The PR monitor's settings in words: the Allow card for turning auto-merge
/// on by default, the notice of its answer, and the settings line tools
/// show.
class const PullRequestConfigDescriptionBuilder() {
  /// The card's title, also what the user's list of requests shows.
  static const String approvalTitle = "Sesori: PR monitor auto-merge";

  /// The card's Markdown: what [change] turns on, given [config] before it.
  String approvalBody({required PullRequestAutoMergeDefaultChange change, required PullRequestMonitorConfig config}) {
    final what = switch (change) {
      PullRequestGlobalAutoMerge() => "Turn auto-merge on by default for **every repository**",
      PullRequestRepositoryAutoMerge(:final repositoryKey) => "Turn auto-merge on by default for **$repositoryKey**",
      PullRequestRepositoryAutoMergeCleared(:final repositoryKey) =>
        "Remove **$repositoryKey**'s own auto-merge setting (off), so it follows the default for every repository, "
            "which is on",
    };
    final kept = config.repositoryAutoMerge.isNotEmpty && change is PullRequestGlobalAutoMerge
        ? " Repositories with their own setting keep it."
        : "";
    return "$what?\n\n"
        "A PR an agent then watches without choosing auto-merge is squash-merged, titled with only the PR title, as "
        "soon as the agent marks it ready, without waiting for human review.$kept PRs already watched keep their "
        "choice.";
  }

  /// The card's Markdown for turning auto-merge on for one watched PR.
  String pullRequestApprovalBody({required PullRequestTarget target}) =>
      "Turn auto-merge on for **${target.displayKey}**?\n\n"
      "The agent asked for it. Once the agent marks the PR ready, it is squash-merged, titled with only the PR title, "
      "without waiting for human review.";

  /// The notice line the user sees once they answered a PR's card.
  String pullRequestOutcomeSummary({required PullRequestTarget target, required PullRequestApprovalAnswer answer}) =>
      "PR monitor: auto-merge for ${target.displayKey} ${_answered(answer: answer)}";

  /// What the agent reads beside [pullRequestOutcomeSummary].
  String pullRequestOutcomeGuidance({required PullRequestTarget target, required PullRequestApprovalAnswer answer}) =>
      switch (answer) {
        PullRequestApprovalAnswer.allowed =>
          "The user allowed auto-merge for ${target.displayKey}: marking it ready, automatically or with "
              "mark_pr_ready, is now the merge approval, and Sesori makes one squash-merge attempt for the accepted "
              "head. Assess the PR again, and once nothing is left to do, call mark_pr_ready; never hold it back to "
              "wait for a human.",
        PullRequestApprovalAnswer.declined =>
          "The user declined auto-merge for ${target.displayKey}; it stays off, so marking it ready hands it to a "
              "human reviewer. Do not ask again unless the user does.",
        PullRequestApprovalAnswer.outdated =>
          "The user allowed auto-merge for ${target.displayKey}, but this session no longer watches it, so nothing "
              "changed.",
      };

  /// The notice line the user sees once they answered.
  String outcomeSummary({
    required PullRequestAutoMergeDefaultChange change,
    required PullRequestApprovalAnswer answer,
  }) => "PR monitor: auto-merge by default for ${_scope(change: change)} ${_answered(answer: answer)}";

  String _answered({required PullRequestApprovalAnswer answer}) => switch (answer) {
    PullRequestApprovalAnswer.allowed => "allowed",
    PullRequestApprovalAnswer.declined => "declined",
    PullRequestApprovalAnswer.outdated => "not applied",
  };

  /// What the agent reads beside [outcomeSummary]; [config] is the settings
  /// now in effect.
  String outcomeGuidance({
    required PullRequestAutoMergeDefaultChange change,
    required PullRequestApprovalAnswer answer,
    required PullRequestMonitorConfig config,
  }) => switch (answer) {
    PullRequestApprovalAnswer.allowed =>
      "The user allowed turning auto-merge on by default for ${_scope(change: change)}. PRs watched there from now "
          "on without choosing auto-merge get it; PRs already watched keep their choice. ${settingsText(config: config)}",
    PullRequestApprovalAnswer.declined =>
      "The user declined turning auto-merge on by default for ${_scope(change: change)}; nothing changed. Do not ask "
          "again unless the user does. ${settingsText(config: config)}",
    PullRequestApprovalAnswer.outdated =>
      "The user allowed turning auto-merge on by default for ${_scope(change: change)}, but the auto-merge settings "
          "changed while they decided, so what they allowed no longer matches and nothing was applied. Call "
          "configure_pr_monitor again only if it is still wanted. ${settingsText(config: config)}",
  };

  /// `Auto-merge by default: off (owner/repo: on). Reports wait …`.
  String settingsText({required PullRequestMonitorConfig config}) {
    final overrides = [
      for (final MapEntry(key: repositoryKey, value: enabled) in config.repositoryAutoMerge.entries)
        "$repositoryKey: ${_onOff(enabled: enabled)}",
    ];
    final idle = switch (config.idleReminderMinutes) {
      final minutes? => "an open PR that stays still for $minutes min gets an idle reminder",
      null => "idle reminders are off",
    };
    return "Auto-merge by default: ${_onOff(enabled: config.autoMerge)}"
        "${overrides.isEmpty ? "" : " (${overrides.join(", ")})"}. Reports wait for ${config.quietMinutes} min of "
        "quiet, running CI holds them for up to ${config.ciWaitMinutes} min, and $idle.";
  }

  String _scope({required PullRequestAutoMergeDefaultChange change}) => switch (change) {
    PullRequestGlobalAutoMerge() => "every repository",
    PullRequestRepositoryAutoMerge(:final repositoryKey) ||
    PullRequestRepositoryAutoMergeCleared(:final repositoryKey) => repositoryKey,
  };

  String _onOff({required bool enabled}) => enabled ? "on" : "off";
}
