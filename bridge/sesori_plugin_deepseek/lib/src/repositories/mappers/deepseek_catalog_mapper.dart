import "package:acp_plugin/acp_plugin.dart" show AcpNewSessionResult;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/deepseek_protocol_dto.dart";

class const DeepSeekCatalogMapper() {
  PluginSessionOptions map(DeepSeekCatalogResponseDto response) {
    final providers = [
      for (final provider in response.providers)
        if (provider.models.isNotEmpty)
          PluginProvider(
            id: provider.id,
            name: provider.name,
            authType: PluginProviderAuthType.unknown,
            models: [
              for (final model in provider.models)
                PluginModel(
                  id: model.id,
                  name: model.name,
                  variants: [
                    ?model.defaultReasoningEffort,
                    for (final effort in model.reasoningEfforts)
                      if (effort != model.defaultReasoningEffort) effort,
                  ],
                  family: null,
                  isAvailable: true,
                  releaseDate: null,
                ),
            ],
            defaultModelID: provider.models.any((model) => model.id == response.defaultSelectionId)
                ? response.defaultSelectionId
                : null,
          ),
    ];
    final defaultModel = response.defaultSelectionId == null
        ? null
        : response.providers
              .expand((provider) => [for (final model in provider.models) (provider: provider, model: model)])
              .where((entry) => entry.model.id == response.defaultSelectionId)
              .firstOrNull;
    return PluginSessionOptions(
      agents: [
        PluginAgent(
          name: response.agent.name,
          description: "${response.agent.name} session",
          model: defaultModel == null
              ? null
              : PluginAgentModel(
                  modelID: defaultModel.model.id,
                  providerID: defaultModel.provider.id,
                  variant: defaultModel.model.defaultReasoningEffort,
                ),
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ],
      providers: PluginProvidersResult(providers: providers),
      commands: [
        for (final command in response.commands)
          PluginCommand(
            name: command.name,
            description: command.description,
            provider: null,
            source: PluginCommandSource.command,
          ),
      ],
      completeness: response.failures.isEmpty
          ? PluginSessionOptionsCompleteness.complete
          : PluginSessionOptionsCompleteness.partial,
    );
  }

  ({String modelId, String providerId, String? variant})? mapSessionSelection({
    required AcpNewSessionResult result,
  }) {
    final modelOption = result.configOptions.where((option) => option["id"] == "deepseek.model").firstOrNull;
    final modelId = modelOption?["currentValue"];
    if (modelId is! String || modelId.isEmpty) return null;
    String? providerId;
    final groups = modelOption?["options"];
    if (groups is List) {
      for (final rawGroup in groups) {
        if (rawGroup is! Map) continue;
        final options = rawGroup["options"];
        if (options is! List || !options.any((option) => option is Map && option["value"] == modelId)) continue;
        final group = rawGroup["group"];
        if (group is String && group.isNotEmpty) providerId = group;
        break;
      }
    }
    if (providerId == null) return null;
    final reasoningOption = result.configOptions
        .where((option) => option["id"] == "deepseek.reasoning_effort")
        .firstOrNull;
    final variant = reasoningOption?["currentValue"];
    return (
      modelId: modelId,
      providerId: providerId,
      variant: variant is String && variant.isNotEmpty ? variant : null,
    );
  }
}
