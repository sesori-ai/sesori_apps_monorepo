import "../repositories/models/pull_request_monitor_config.dart";
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

  /// The notice line the user sees once they answered.
  String outcomeSummary({required PullRequestAutoMergeDefaultChange change, required bool allowed}) =>
      "PR monitor: auto-merge by default for ${_scope(change: change)} ${allowed ? "allowed" : "declined"}";

  /// What the agent reads beside [outcomeSummary]; [config] is the settings
  /// now in effect.
  String outcomeGuidance({
    required PullRequestAutoMergeDefaultChange change,
    required bool allowed,
    required PullRequestMonitorConfig config,
  }) => allowed
      ? "The user allowed turning auto-merge on by default for ${_scope(change: change)}. PRs watched there from now "
            "on without choosing auto-merge get it; PRs already watched keep their choice. ${settingsText(config: config)}"
      : "The user declined turning auto-merge on by default for ${_scope(change: change)}; nothing changed. Do not ask "
            "again unless the user does. ${settingsText(config: config)}";

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
