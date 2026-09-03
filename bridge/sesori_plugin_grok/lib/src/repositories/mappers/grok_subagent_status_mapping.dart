import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../models/grok_subagent_status.dart";

extension GrokSubagentStatusMapping on GrokSubagentStatus {
  /// The subtask lifecycle state a finished Grok sub-agent maps to.
  PluginToolStatus toPluginToolStatus() => switch (this) {
    GrokSubagentStatus.completed => PluginToolStatus.completed,
    GrokSubagentStatus.failed => PluginToolStatus.error,
    GrokSubagentStatus.cancelled => PluginToolStatus.cancelled,
    GrokSubagentStatus.unknown => PluginToolStatus.unknown,
  };
}
