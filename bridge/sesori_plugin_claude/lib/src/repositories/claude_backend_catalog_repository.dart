import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/claude_backend_catalog_dto.dart";
import "../models/claude_agent_selection.dart";
import "../models/claude_effort_level.dart";

final class ClaudeBackendCatalog {
  const ClaudeBackendCatalog({required this.agents, required this.providers, required this.commands});

  final List<PluginAgent> agents;
  final PluginProvidersResult providers;
  final List<PluginCommand> commands;
}

/// Maps Claude's backend catalog into the backend-neutral plugin contract.
final class ClaudeBackendCatalogRepository {
  const ClaudeBackendCatalogRepository();

  static const String providerId = "anthropic";

  ClaudeBackendCatalog map({required Map<String, Object?> handshake}) {
    final dto = ClaudeBackendCatalogDto.fromJson(handshake);
    final models = [
      for (final model in dto.models) ?_model(model),
    ];
    final defaultModelId = models.any((model) => model.id == "default") ? "default" : models.firstOrNull?.id;
    final agentModel = defaultModelId == null
        ? null
        : PluginAgentModel(modelID: defaultModelId, providerID: providerId, variant: null);

    return ClaudeBackendCatalog(
      agents: List.unmodifiable([
        for (final selection in ClaudeAgentSelection.values)
          PluginAgent(
            name: selection.displayName,
            description: selection.description,
            model: agentModel,
            mode: PluginAgentMode.primary,
            hidden: false,
          ),
      ]),
      providers: PluginProvidersResult(
        providers: models.isEmpty
            ? const []
            : [
                PluginProvider.anthropic(
                  id: providerId,
                  name: "Anthropic",
                  authType: PluginProviderAuthType.oauth,
                  models: models,
                  defaultModelID: defaultModelId,
                ),
              ],
      ),
      commands: List.unmodifiable([
        for (final command in dto.commands) ?_command(command),
      ]),
    );
  }

  PluginModel? _model(ClaudeModelDto dto) {
    final id = dto.value?.trim();
    if (id == null || id.isEmpty) return null;
    final displayName = dto.displayName?.trim();
    final resolvedModel = dto.resolvedModel?.trim();
    final variants = dto.supportsEffort == true
        ? [
            for (final raw in dto.supportedEffortLevels)
              if (ClaudeEffortLevel.tryParse(raw) case final level?) level.wireValue,
          ]
        : const <String>[];
    return PluginModel(
      id: id,
      name: displayName?.isNotEmpty == true
          ? displayName!
          : resolvedModel?.isNotEmpty == true
          ? resolvedModel!
          : id,
      variants: variants,
      family: null,
      isAvailable: true,
      releaseDate: null,
    );
  }

  PluginCommand? _command(ClaudeCommandDto dto) {
    final name = dto.name?.trim();
    if (name == null || name.isEmpty) return null;
    final description = dto.description?.trim();
    final hint = dto.argumentHint?.trim();
    return PluginCommand(
      name: name,
      description: description?.isNotEmpty == true ? description : null,
      hints: [if (hint?.isNotEmpty == true) hint!],
      provider: null,
      source: PluginCommandSource.command,
    );
  }
}
