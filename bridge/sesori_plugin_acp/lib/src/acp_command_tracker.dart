import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_protocol.dart";
import "acp_stdio_client.dart";

/// Tracks the slash commands the agent last advertised via the ACP
/// `available_commands_update` notification, so the plugin's `getCommands`
/// can serve them (ACP has no request endpoint for commands).
///
/// The snapshot is process-global and the last update wins: ACP scopes the
/// notification per session, but the commands are agent-global for every
/// shipping backend, and `getCommands` is project-scoped — a per-session
/// cache would invent scoping the plugin API can't express.
class AcpCommandTracker {
  /// The most recently advertised commands (empty until the first update).
  List<PluginCommand> get commands => List.unmodifiable(_commands);
  List<PluginCommand> _commands = const [];

  /// Drops commands advertised by the prior ACP process.
  void clear() => _commands = const [];

  /// Consumes one agent notification; a no-op unless it is a
  /// `session/update` carrying an `available_commands_update`.
  void consume(AcpNotification notification) {
    if (notification.method != AcpMethods.sessionUpdate) return;
    final update = notification.params["update"];
    if (update is! Map) return;
    final map = update.cast<String, dynamic>();
    if (map["sessionUpdate"] != "available_commands_update") return;
    _commands = _parse(map["availableCommands"]);
  }

  /// Fail-soft parse: a malformed entry is skipped rather than dropping the
  /// whole batch — command advertisement must never break the event flow.
  static List<PluginCommand> _parse(Object? raw) {
    if (raw is! List) return const [];
    final commands = <PluginCommand>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final name = map["name"];
      if (name is! String || name.isEmpty) continue;
      final description = map["description"];
      final input = map["input"];
      final hint = input is Map ? input["hint"] : null;
      commands.add(
        PluginCommand(
          name: name,
          description: description is String && description.isNotEmpty ? description : null,
          hints: [if (hint is String && hint.isNotEmpty) hint],
          provider: null,
          source: PluginCommandSource.command,
        ),
      );
    }
    return commands;
  }
}
