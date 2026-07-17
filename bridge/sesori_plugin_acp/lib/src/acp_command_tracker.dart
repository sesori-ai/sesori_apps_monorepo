import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "repositories/models/acp_notification_record.dart";

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

  void consume(AcpNotificationRecord notification) {
    if (notification is AcpAvailableCommandsChangedRecord) {
      _commands = notification.commands;
    }
  }
}
