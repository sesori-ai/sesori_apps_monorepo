import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_monitor_config.dart";
import "package:sesori_tool_pr_monitor/src/services/models/pull_request_config_change.dart";
import "package:sesori_tool_pr_monitor/src/services/pull_request_config_description_builder.dart";
import "package:test/test.dart";

void main() {
  const builder = PullRequestConfigDescriptionBuilder();
  final withOverride = PullRequestMonitorConfig.defaults.copyWith(repositoryAutoMerge: {"sesori/example": false});

  test("the Allow card names the scope it turns auto-merge on for", () {
    expect(
      builder.approvalBody(change: const PullRequestGlobalAutoMerge(enabled: true), config: withOverride),
      "Turn auto-merge on by default for **every repository**?\n\n"
      "A PR an agent then watches without choosing auto-merge is squash-merged, titled with only the PR title, as "
      "soon as the agent marks it ready, without waiting for human review. Repositories with their own setting keep "
      "it. PRs already watched keep their choice.",
    );
    expect(
      builder.approvalBody(
        change: const PullRequestRepositoryAutoMerge(repositoryKey: "sesori/other", enabled: true),
        config: PullRequestMonitorConfig.defaults,
      ),
      startsWith("Turn auto-merge on by default for **sesori/other**?\n\nA PR an agent"),
    );
  });

  test("the settings line lists repository settings and reminders that are off", () {
    expect(
      builder.settingsText(config: withOverride.copyWith(autoMerge: true, idleReminderMinutes: 0)),
      "Auto-merge by default: on (sesori/example: off). Reports wait for 2 min of quiet, running CI holds them for "
      "up to 30 min, and idle reminders are off.",
    );
  });
}
