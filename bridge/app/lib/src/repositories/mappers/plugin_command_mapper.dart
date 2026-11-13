import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
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

extension PluginCommandInvocationMapping on PluginCommandInvocation {
  /// The arguments lose the bridge's worktree note, as the message's text
  /// parts do, since a plugin names them from the prompt the bridge sent.
  CommandInvocation toShared() => CommandInvocation(
    name: name,
    source: source.toShared(),
    arguments: switch (arguments) {
      final arguments? => stripWorktreeSystemContext(text: arguments),
      null => null,
    },
  );
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
    template: null, // template,
    hints: hints,
    description: description,
    agent: agent,
    model: model,
    provider: provider,
    source: source?.toShared(),
    subtask: subtask,
  );
}
