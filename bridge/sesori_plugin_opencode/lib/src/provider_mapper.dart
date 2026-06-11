import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginModel, PluginProvider, PluginProviderAuthType, PluginProvidersResult;

import "models/openapi/config_providers_response.g.dart";

enum _ProviderModelStatus {
  active,
  alpha,
  beta,
  deprecated,
  unknown,
}

/// Maps an OpenCode [ConfigProvidersResponse] to the plugin interface
/// [PluginProvidersResult], optionally filtering to connected providers only.
PluginProvidersResult mapProviderResponse({
  required ConfigProvidersResponse response,
}) {
  final providers = response.providers.map((providerInfo) {
    final models = providerInfo.models.values
        .map(
          (m) => PluginModel(
            id: m.id,
            name: m.name,
            variants: _enabledVariants(variants: m.variants),
            family: m.family,
            isAvailable: _isModelAvailable(
              status: _parseProviderModelStatus(rawStatus: m.status, modelId: m.id),
            ),
            releaseDate: _parseReleaseDate(m.releaseDate),
          ),
        )
        .toList();

    return _mapProvider(
      id: providerInfo.id,
      name: providerInfo.name,
      models: models,
      defaultModels: response.defaultValue,
    );
  }).toList();

  return PluginProvidersResult(providers: providers);
}

_ProviderModelStatus _parseProviderModelStatus({
  required String rawStatus,
  required String modelId,
}) {
  return switch (rawStatus) {
    "active" => _ProviderModelStatus.active,
    "alpha" => _ProviderModelStatus.alpha,
    "beta" => _ProviderModelStatus.beta,
    "deprecated" => _ProviderModelStatus.deprecated,
    final unknown => () {
      Log.w("Unknown model status: $unknown for model $modelId, treating as available");
      return _ProviderModelStatus.unknown;
    }(),
  };
}

List<String> _enabledVariants({required Map<String, Map<String, dynamic>>? variants}) {
  if (variants == null) return const <String>[];
  return variants.entries.where((entry) => entry.value["disabled"] != true).map((entry) => entry.key).toList();
}

/// Parses a `release_date` string from models.dev into a [DateTime].
///
/// Dart's [DateTime.tryParse] only accepts `YYYY-MM-DD` (and full ISO 8601);
/// models.dev emits the shorter `YYYY-MM` form for some providers (e.g.
/// `kimi-for-coding`, where `release_date` is `2025-11` rather than
/// `2025-11-01`). Without the `YYYY-MM-01` fallback, every model in those
/// providers gets a `null` `releaseDate`, which makes any date-based
/// downstream filter (e.g. the mobile model picker's "newest in family"
/// default) fall back to iteration order — and on `kimi-for-coding` that
/// surfaced the oldest model ("Kimi K2 Thinking") instead of the newest
/// ("Kimi K2.6").
DateTime? _parseReleaseDate(String? dateStr) {
  if (dateStr == null) return null;
  return DateTime.tryParse(dateStr) ?? DateTime.tryParse("$dateStr-01");
}

bool _isModelAvailable({required _ProviderModelStatus status}) {
  return switch (status) {
    _ProviderModelStatus.active ||
    _ProviderModelStatus.alpha ||
    _ProviderModelStatus.beta ||
    _ProviderModelStatus.unknown => true,
    _ProviderModelStatus.deprecated => false,
  };
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
