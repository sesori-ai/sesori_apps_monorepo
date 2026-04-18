import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginCommandSourceMapping on PluginCommandSource {
  CommandSource toShared() => switch (this) {
    PluginCommandSource.command => CommandSource.command,
    PluginCommandSource.mcp => CommandSource.mcp,
    PluginCommandSource.skill => CommandSource.skill,
    PluginCommandSource.unknown => CommandSource.unknown,
  };
}

extension PluginCommandMapping on PluginCommand {
  /// Maps to shared [CommandInfo] for the mobile client.
  ///
  /// The `template` field is intentionally excluded: it contains the full
  /// prompt text (often thousands of characters) that the mobile UI never
  /// displays. Stripping it shrinks a typical response from ~400 KB to ~20 KB,
  /// preventing relay timeouts and WebSocket frame issues.
  CommandInfo toSharedCommandInfo() => CommandInfo(
    name: name,
    hints: hints,
    description: description,
    agent: agent,
    model: model,
    provider: provider,
    source: source?.toShared(),
    subtask: subtask,
  );
}
