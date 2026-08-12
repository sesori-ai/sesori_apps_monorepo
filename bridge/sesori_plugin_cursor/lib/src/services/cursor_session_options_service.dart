import "package:acp_plugin/acp_plugin.dart" show AcpCommandTracker;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../trackers/cursor_catalog_tracker.dart";
import "cursor_catalog_service.dart";

/// Owns Cursor's coherent command, mode, and model option snapshot.
class CursorSessionOptionsService({
    required CursorCatalogService catalogService,
    required CursorCatalogTracker catalogTracker,
    required AcpCommandTracker commandTracker,
    required String launchDirectory,
  }) {
  this : _catalogService = catalogService,
       _catalogTracker = catalogTracker,
       _commandTracker = commandTracker,
       _launchDirectory = normalizeProjectDirectory(directory: launchDirectory);

  static const String compactionCommandName = "compact";
  static const String _cursorCompactionCommandName = "summarize";
  static const String _providerId = "cursor";

  static const PluginCommand _compactionCommand = PluginCommand(
    name: compactionCommandName,
    description: "Summarize the conversation so far to free up the context window",
    provider: null,
    source: PluginCommandSource.command,
  );

  final CursorCatalogService _catalogService;
  final CursorCatalogTracker _catalogTracker;
  final AcpCommandTracker _commandTracker;
  final String _launchDirectory;

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    final scope = _scope(projectId: projectId);
    switch (discoveryMode) {
      case PluginSessionOptionsDiscoveryMode.reuse:
        await _catalogService.ensureCatalog(scope: scope);
      case PluginSessionOptionsDiscoveryMode.refresh:
        final succeeded = await _catalogService.refreshCatalog(scope: scope);
        if (!succeeded) return const PluginSessionOptionsDiscoveryResult.failed();
    }
    return PluginSessionOptionsDiscoveryResult.observed(options: _snapshot());
  }

  Future<void> warmCatalog() => _catalogService.ensureCatalog(scope: _launchDirectory);

  Future<List<PluginCommand>> listCommands({required String? projectId}) async {
    await _catalogService.ensureCatalog(scope: _scope(projectId: projectId));
    return _commands();
  }

  Future<List<PluginAgent>> listAgents({required String projectId}) async {
    await _catalogService.ensureCatalog(scope: _scope(projectId: projectId));
    return _agents();
  }

  Future<PluginProvidersResult> listProviders({required String projectId}) async {
    await _catalogService.ensureCatalog(scope: _scope(projectId: projectId));
    return _providers();
  }

  String backendCommandFor({required String command}) =>
      command == compactionCommandName ? _cursorCompactionCommandName : command;

  PluginSessionOptions _snapshot() => PluginSessionOptions(
    agents: _agents(),
    providers: _providers(),
    commands: _commands(),
    completeness: _catalogTracker.isComplete && _commandTracker.hasSnapshot
        ? PluginSessionOptionsCompleteness.complete
        : PluginSessionOptionsCompleteness.partial,
  );

  List<PluginCommand> _commands() {
    final commands = _commandTracker.commands;
    if (commands.any((command) => command.name == compactionCommandName)) {
      return commands;
    }
    return [...commands, _compactionCommand];
  }

  List<PluginAgent> _agents() {
    final modes = _catalogTracker.modes;
    if (modes.isEmpty) {
      return const [
        PluginAgent(
          name: "Cursor",
          description: "Cursor CLI session",
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ];
    }

    final ordered = modes.toList(growable: true);
    final defaultMode = _catalogTracker.defaultModeId;
    if (defaultMode != null) {
      final defaultIndex = ordered.indexWhere((mode) => mode.value == defaultMode);
      if (defaultIndex > 0) ordered.insert(0, ordered.removeAt(defaultIndex));
    }
    return [
      for (final mode in ordered)
        PluginAgent(
          name: mode.name,
          description: mode.description,
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
    ];
  }

  PluginProvidersResult _providers() {
    final models = _catalogTracker.models;
    if (models.isEmpty) return const PluginProvidersResult(providers: []);
    return PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: _providerId,
          name: "Cursor",
          authType: PluginProviderAuthType.unknown,
          models: [
            for (final model in models)
              PluginModel(
                id: model.value,
                name: model.name,
                variants: _catalogTracker.variantsForModel(modelId: model.value),
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
          ],
          defaultModelID: _catalogTracker.currentModelId ?? _catalogTracker.firstModelId,
        ),
      ],
    );
  }

  String _scope({required String? projectId}) {
    final trimmed = projectId?.trim();
    return trimmed == null || trimmed.isEmpty ? _launchDirectory : normalizeProjectDirectory(directory: trimmed);
  }
}
