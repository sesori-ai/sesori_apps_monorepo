import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginModel, PluginProvider, PluginProviderAuthType, PluginProvidersResult;

import "models/openapi/config_providers_response.g.dart";
import "models/openapi/model.g.dart";

enum _ProviderModelStatus() {
  active,
  alpha,
  beta,
  deprecated,
  unknown,
}

/// Maps an OpenCode [ConfigProvidersResponse] to the plugin interface
/// [PluginProvidersResult], optionally filtering to connected providers only.
///
/// Models are listed in picker order: newest release first, undated models
/// last, ties by name. OpenCode's catalog carries no strength ranking, so the
/// release date is the best signal available.
PluginProvidersResult mapProviderResponse({
  required ConfigProvidersResponse response,
}) {
  final providers = response.providers.map((providerInfo) {
    final models =
        providerInfo.models.values
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
            .toList()
          ..sort(_newestFirst);

    return _mapProvider(
      id: providerInfo.id,
      name: providerInfo.name,
      models: models,
    );
  }).toList();

  return PluginProvidersResult(providers: providers);
}

int _newestFirst(PluginModel a, PluginModel b) {
  final aDate = a.releaseDate;
  final bDate = b.releaseDate;
  if (aDate == null && bDate != null) return 1;
  if (bDate == null && aDate != null) return -1;
  final byDate = aDate == null || bDate == null ? 0 : bDate.compareTo(aDate);
  return byDate != 0 ? byDate : a.name.compareTo(b.name);
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
  return PluginProvider(
    id: id,
    name: name,
    authType: switch (id.toLowerCase()) {
      "anthropic" ||
      "openai" ||
      "google" ||
      "mistral" ||
      "groq" ||
      "xai" ||
      "deepseek" ||
      "azure" => PluginProviderAuthType.apiKey,
      _ => PluginProviderAuthType.unknown,
    },
    models: models,
    defaultModelID: null,
  );
}
