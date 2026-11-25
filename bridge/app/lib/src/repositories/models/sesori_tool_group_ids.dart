import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGroupId;
import "package:sesori_tool_pr_monitor/sesori_tool_pr_monitor.dart" show PullRequestMonitorToolGroup;

/// The ids of the tool groups this bridge serves, known before the groups are
/// built: launches, the CLI and scheduled runs read them from settings.
abstract final class SesoriToolGroupIds() {
  static const SesoriToolGroupId tasks = SesoriToolGroupId("tasks");
  static const SesoriToolGroupId pages = SesoriToolGroupId("pages");
  static const SesoriToolGroupId wakeUps = SesoriToolGroupId("wake_ups");
  static const SesoriToolGroupId prMonitor = PullRequestMonitorToolGroup.groupId;

  /// Every group, in the order the server lists their tools. The orchestrator
  /// asserts that its groups match.
  static const List<SesoriToolGroupId> all = [tasks, pages, wakeUps, prMonitor];

  /// The served group [value] names, or null for any other id.
  static SesoriToolGroupId? parse({required String value}) {
    for (final id in all) {
      if (id.value == value) return id;
    }
    return null;
  }
}
