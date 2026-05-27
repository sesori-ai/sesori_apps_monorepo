import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgePluginApi, PluginModel, PluginProvider, PluginProviderAuthType;
import "package:sesori_shared/sesori_shared.dart" show ProviderListResponse;

import "../api/codex_defaults_api.dart";
import "mappers/plugin_provider_mapper.dart";

/// Wraps [BridgePluginApi.getProviders] and maps plugin models to shared types.
class ProviderRepository {
  final BridgePluginApi _plugin;
  final CodexDefaultsApi _codexDefaultsApi;

  ProviderRepository({
    required BridgePluginApi plugin,
    required CodexDefaultsApi codexDefaultsApi,
  }) : _plugin = plugin,
       _codexDefaultsApi = codexDefaultsApi;

  Future<ProviderListResponse> getProviders({required String projectId}) async {
    final result = await _plugin.getProviders(projectId: projectId);
    final effectiveProviders = result.providers.isNotEmpty || _plugin.id != "codex"
        ? result.providers
        : _synthesizeCodexProviders(projectId: projectId);
    final providers = effectiveProviders.map((p) => p.toSharedProviderInfo()).toList();
    return ProviderListResponse(items: providers, connectedOnly: true);
  }

  List<PluginProvider> _synthesizeCodexProviders({required String projectId}) {
    final defaults = _codexDefaultsApi.readProjectDefaults(projectId: projectId);
    final modelId = defaults.modelId;
    final providerId = defaults.modelProvider;
    if (modelId == null || providerId == null) {
      return const [];
    }

    return [
      PluginProvider.custom(
        id: providerId,
        name: _displayName(providerId),
        authType: PluginProviderAuthType.unknown,
        models: [
          PluginModel(
            id: modelId,
            name: modelId,
            variants: const [],
            family: null,
            isAvailable: true,
            releaseDate: null,
          ),
        ],
        defaultModelID: modelId,
      ),
    ];
  }

  String _displayName(String providerId) {
    return switch (providerId.toLowerCase()) {
      "openai" => "OpenAI",
      "anthropic" => "Anthropic",
      "google" => "Google",
      "mistral" => "Mistral",
      "groq" => "Groq",
      "xai" => "xAI",
      "deepseek" => "DeepSeek",
      "azure" => "Azure OpenAI",
      "amazon-bedrock" || "bedrock" => "Amazon Bedrock",
      _ => providerId,
    };
  }
}
