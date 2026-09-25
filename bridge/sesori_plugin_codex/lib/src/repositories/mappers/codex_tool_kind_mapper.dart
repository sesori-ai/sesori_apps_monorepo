import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Classifies the plugin's canonical Codex tool names. Codex reads and searches
/// files through shell commands, so those calls report as commands.
abstract final class CodexToolKindMapper() {
  static PluginToolKind map({required String tool}) => switch (tool) {
    "shell" => PluginToolKind.command,
    "edit" => PluginToolKind.edit,
    "web_search" => PluginToolKind.search,
    _ => PluginToolKind.other,
  };
}
