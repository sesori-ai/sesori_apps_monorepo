import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Classifies Claude Code's built-in tool names; MCP and other tools are other.
abstract final class ClaudeToolKindMapper() {
  static PluginToolKind map({required String? name}) => switch (name?.toLowerCase()) {
    "read" || "notebookread" => PluginToolKind.read,
    "edit" || "multiedit" || "notebookedit" || "write" => PluginToolKind.edit,
    "bash" => PluginToolKind.command,
    "grep" || "glob" || "ls" || "websearch" => PluginToolKind.search,
    _ => PluginToolKind.other,
  };
}
