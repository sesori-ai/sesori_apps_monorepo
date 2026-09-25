import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Classifies Pi's built-in tool names; extension tools are other.
abstract final class PiToolKindMapper() {
  static PluginToolKind map({required String name}) => switch (name.toLowerCase()) {
    "read" => PluginToolKind.read,
    "edit" || "write" => PluginToolKind.edit,
    "bash" => PluginToolKind.command,
    "grep" || "find" || "ls" => PluginToolKind.search,
    _ => PluginToolKind.other,
  };
}
