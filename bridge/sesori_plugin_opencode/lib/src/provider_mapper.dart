import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginModel, PluginProvider, PluginProviderAuthType, PluginProvidersResult;

import "models/openapi/config_providers_response.g.dart";
import "models/openapi/model.g.dart";

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
    );
  }).toList();

  return PluginProvidersResult(providers: providers);
}

_ProviderModelStatus _parseProviderModelStatus({
  required ModelStatus rawStatus,
  required String modelId,
}) {
  return switch (rawStatus) {
    ModelStatus.active => _ProviderModelStatus.active,
    ModelStatus.alpha => _ProviderModelStatus.alpha,
    ModelStatus.beta => _ProviderModelStatus.beta,
    ModelStatus.deprecated => _ProviderModelStatus.deprecated,
    ModelStatus.unknown => () {
      Log.w("Unknown model status for model $modelId, treating as available");
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
}) {
  // OpenCode's per-provider `default` map is frequently stale (e.g. Kimi).
  // Omit it so clients fall back to newest-by-releaseDate selection instead
  // of trusting the API default. Plugins that publish a trustworthy default
  // (e.g. Cursor's ACP current model) set defaultModelID themselves.
  return switch (id.toLowerCase()) {
    "anthropic" => PluginProvider.anthropic(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: null,
    ),
    "openai" => PluginProvider.openAI(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: null,
    ),
    "google" => PluginProvider.google(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: null,
    ),
    "mistral" => PluginProvider.mistral(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: null,
    ),
    "groq" => PluginProvider.groq(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: null,
    ),
    "xai" => PluginProvider.xAI(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: null,
    ),
    "deepseek" => PluginProvider.deepseek(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: null,
    ),
    "amazon-bedrock" || "bedrock" => PluginProvider.amazonBedrock(
      id: id,
      name: name,
      authType: PluginProviderAuthType.unknown,
      models: models,
      defaultModelID: null,
    ),
    "azure" => PluginProvider.azure(
      id: id,
      name: name,
      authType: PluginProviderAuthType.apiKey,
      models: models,
      defaultModelID: null,
    ),
    _ => PluginProvider.custom(
      id: id,
      name: name,
      authType: PluginProviderAuthType.unknown,
      models: models,
      defaultModelID: null,
    ),
  };
}
