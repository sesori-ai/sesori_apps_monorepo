import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class const OmpCatalogOption({
  required final String value,
  required final String name,
  required final String? description,
});

/// One exact OMP `<provider>/<model-id>` config value.
class const OmpCatalogModel({
  required final String value,
  required final String providerId,
  required final String modelId,
  required final String name,
});

class OmpThinkingOptions({
  required final String configId,
  required List<String> variants,
  required final String? currentValue,
}) {
  final List<String> variants = List.unmodifiable(variants);
}

class OmpSessionConfigSnapshot({
  required final String? modelConfigId,
  required List<OmpCatalogModel> models,
  required final String? currentModelValue,
  required final String? modeConfigId,
  required List<OmpCatalogOption> modes,
  required final String? currentModeValue,
  required final OmpThinkingOptions? thinking,
}) {
  final List<OmpCatalogModel> models = List.unmodifiable(models);
  final List<OmpCatalogOption> modes = List.unmodifiable(modes);
}

class const OmpCatalogSession({required final String sessionId, required final OmpSessionConfigSnapshot snapshot});

class OmpProjectCatalog({
  required final String modelConfigId,
  required List<OmpCatalogModel> models,
  required final String? defaultModelValue,
  required final String? modeConfigId,
  required List<OmpCatalogOption> modes,
  required final String? defaultModeValue,
  required Map<String, OmpThinkingOptions> thinkingByModel,
  required List<PluginCommand> commands,
  required final PluginSessionOptionsCompleteness completeness,
}) {
  final List<OmpCatalogModel> models = List.unmodifiable(models);
  final List<OmpCatalogOption> modes = List.unmodifiable(modes);
  final Map<String, OmpThinkingOptions> thinkingByModel = Map.unmodifiable(thinkingByModel);
  final List<PluginCommand> commands = List.unmodifiable(commands);
}

sealed class const OmpCatalogDiscoveryResult();

final class const OmpCatalogObserved({required final OmpProjectCatalog catalog}) extends OmpCatalogDiscoveryResult;

final class const OmpCatalogNoModels() extends OmpCatalogDiscoveryResult;

final class const OmpCatalogDiscoveryFailed() extends OmpCatalogDiscoveryResult;

sealed class const OmpOptionsDiscoveryResult();

final class const OmpOptionsObserved({required final PluginSessionOptions options}) extends OmpOptionsDiscoveryResult;

final class const OmpOptionsNoModels() extends OmpOptionsDiscoveryResult;

final class const OmpOptionsDiscoveryFailed() extends OmpOptionsDiscoveryResult;
