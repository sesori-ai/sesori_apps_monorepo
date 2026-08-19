import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/claude_backend_catalog_dto.dart";
import "../models/claude_agent_selection.dart";
import "../models/claude_effort_level.dart";

final class const ClaudeBackendCatalog({
  required final List<PluginAgent> agents,
  required final PluginProvidersResult providers,
  required final List<PluginCommand> commands,
});

/// Maps Claude's backend catalog into the backend-neutral plugin contract.
final class const ClaudeBackendCatalogRepository() {
  static const String providerId = "anthropic";

  /// Claude's own catalog entry that resolves to whichever model and effort the
  /// CLI configuration currently prefers. It is dropped rather than surfaced:
  /// a picker entry named "Default" tells the user nothing about what will run.
  static const String _cliDefaultModelId = "default";

  /// Sesori's default selection, named explicitly in place of [_cliDefaultModelId].
  static const String _defaultModelIdPrefix = "opus";
  static const ClaudeEffortLevel _defaultEffort = ClaudeEffortLevel.high;

  ClaudeBackendCatalog map({required Map<String, Object?> handshake}) {
    final dto = ClaudeBackendCatalogDto.fromJson(handshake);
    final models = [
      for (final model in dto.models) ?_model(model),
    ];
    final defaultModel =
        models.where((model) => model.id.startsWith(_defaultModelIdPrefix)).firstOrNull ?? models.firstOrNull;
    final agentModel = defaultModel == null
        ? null
        : PluginAgentModel(
            modelID: defaultModel.id,
            providerID: providerId,
            variant: defaultModel.variants.contains(_defaultEffort.wireValue) ? _defaultEffort.wireValue : null,
          );

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
                  defaultModelID: defaultModel?.id,
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
    if (id == null || id.isEmpty || id == _cliDefaultModelId) return null;
    final displayName = dto.displayName?.trim();
    final resolvedModel = dto.resolvedModel?.trim();
    final variants = dto.supportsEffort ?? false
        ? [
            for (final raw in dto.supportedEffortLevels)
              if (ClaudeEffortLevel.tryParse(raw) case final level?) level.wireValue,
          ]
        : const <String>[];
    return PluginModel(
      id: id,
      name: displayName?.isNotEmpty ?? false
          ? displayName!
          : resolvedModel?.isNotEmpty ?? false
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
      description: description?.isNotEmpty ?? false ? description : null,
      hints: [if (hint?.isNotEmpty ?? false) hint!],
      provider: null,
      source: PluginCommandSource.command,
    );
  }
}
