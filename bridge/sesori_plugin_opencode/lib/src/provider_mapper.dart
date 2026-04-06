import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginModel, PluginProvider, PluginProviderAuthType, PluginProvidersResult;

import "models/provider_info.dart";

/// Maps an OpenCode [ProviderListResponse] to the plugin interface
/// [PluginProvidersResult], optionally filtering to connected providers only.
PluginProvidersResult mapProviderResponse({
  required ProviderListResponse response,
  required bool connectedOnly,
}) {
  final connectedIds = response.connected.toSet();
  final source = connectedOnly ? response.all.where((p) => connectedIds.contains(p.id)).toList() : response.all;

  final providers = source.map((providerInfo) {
    final models = providerInfo.models.values
        .map(
          (m) => PluginModel(
            id: m.id,
            name: m.name,
            family: m.family,
            isAvailable: switch (m.status) {
              "active" => true,
              "deprecated" => false,
              final unknown => () {
                Log.w("Unknown model status: $unknown for model ${m.id}, treating as available");
                return true;
              }(),
            },
            releaseDate: switch (m.releaseDate) {
              final dateStr? => DateTime.tryParse(dateStr),
              null => null,
            },
          ),
        )
        .toList();
    return _mapProvider(id: providerInfo.id, name: providerInfo.name, models: models, defaultModels: response.defaults);
  }).toList();

  return PluginProvidersResult(providers: providers);
}

PluginProvider _mapProvider({
  required String id,
  required String name,
  required List<PluginModel> models,
  required Map<String, String> defaultModels,
}) {
  final defaultModelID = defaultModels[id];

  return switch (id.toLowerCase()) {
    "anthropic" => PluginProvider.anthropic(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: defaultModelID,
    ),
    "openai" => PluginProvider.openAI(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: defaultModelID,
    ),
    "google" => PluginProvider.google(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: defaultModelID,
    ),
    "mistral" => PluginProvider.mistral(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: defaultModelID,
    ),
    "groq" => PluginProvider.groq(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: defaultModelID,
    ),
    "xai" => PluginProvider.xAI(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: defaultModelID,
    ),
    "deepseek" => PluginProvider.deepseek(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: defaultModelID,
    ),
    "amazon-bedrock" || "bedrock" => PluginProvider.amazonBedrock(
      id: id,
      name: name,
      authType: PluginProviderAuthType.unknown,
      models: models,
      defaultModelID: defaultModelID,
    ),
    "azure" => PluginProvider.azure(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: defaultModelID,
    ),
    _ => PluginProvider.custom(
      id: id,
      name: name,
      authType: PluginProviderAuthType.unknown,
      models: models,
      defaultModelID: defaultModelID,
    ),
  };
}
