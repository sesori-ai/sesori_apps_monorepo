import "package:acp_plugin/acp_plugin.dart" show AcpCommandTracker;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "cursor_catalog_service.dart";

/// Owns Cursor's command catalog and command-name translations.
class CursorCommandService {
  CursorCommandService({
    required CursorCatalogService catalogService,
    required AcpCommandTracker commandTracker,
    required String launchDirectory,
  }) : _catalogService = catalogService,
       _commandTracker = commandTracker,
       _launchDirectory = launchDirectory;

  static const String compactionCommandName = "compact";
  static const String _cursorCompactionCommandName = "summarize";

  static const PluginCommand _compactionCommand = PluginCommand(
    name: compactionCommandName,
    description: "Summarize the conversation so far to free up the context window",
    provider: null,
    source: PluginCommandSource.command,
  );

  final CursorCatalogService _catalogService;
  final AcpCommandTracker _commandTracker;
  final String _launchDirectory;

  Future<List<PluginCommand>> listCommands({required String? projectId}) async {
    await _catalogService.ensureCatalog(scope: projectId ?? _launchDirectory);
    final commands = _commandTracker.commands;
    if (commands.any((command) => command.name == compactionCommandName)) {
      return commands;
    }
    return [...commands, _compactionCommand];
  }

  String backendCommandFor({required String command}) =>
      command == compactionCommandName ? _cursorCompactionCommandName : command;
}
