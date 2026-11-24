import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGroupId;

/// The ids of the tool groups this bridge serves, known before the groups are
/// built: launches, the CLI and scheduled runs read them from settings.
abstract final class SesoriToolGroupIds() {
  static const SesoriToolGroupId tasks = SesoriToolGroupId("tasks");
  static const SesoriToolGroupId pages = SesoriToolGroupId("pages");
  static const SesoriToolGroupId wakeUps = SesoriToolGroupId("wake_ups");

  /// Every group, in the order the server lists their tools. The orchestrator
  /// asserts that its groups match.
  static const List<SesoriToolGroupId> all = [tasks, pages, wakeUps];

  /// The served group [value] names, or null for any other id.
  static SesoriToolGroupId? parse({required String value}) {
    for (final id in all) {
      if (id.value == value) return id;
    }
    return null;
  }
}
