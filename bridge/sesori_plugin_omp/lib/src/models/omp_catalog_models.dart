import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class const OmpCatalogOption({required this.value, required this.name, required this.description}) {
  final String value;
  final String name;
  final String? description;
}

/// One exact OMP `<provider>/<model-id>` config value.
class const OmpCatalogModel({
    required this.value,
    required this.providerId,
    required this.modelId,
    required this.name,
  }) {
  final String value;
  final String providerId;
  final String modelId;
  final String name;
}

class OmpThinkingOptions({
    required this.configId,
    required List<String> variants,
    required this.currentValue,
  }) {
  this : variants = List.unmodifiable(variants);

  final String configId;
  final List<String> variants;
  final String? currentValue;
}

class OmpSessionConfigSnapshot({
    required this.modelConfigId,
    required List<OmpCatalogModel> models,
    required this.currentModelValue,
    required this.modeConfigId,
    required List<OmpCatalogOption> modes,
    required this.currentModeValue,
    required this.thinking,
  }) {
  this : models = List.unmodifiable(models),
       modes = List.unmodifiable(modes);

  final String? modelConfigId;
  final List<OmpCatalogModel> models;
  final String? currentModelValue;
  final String? modeConfigId;
  final List<OmpCatalogOption> modes;
  final String? currentModeValue;
  final OmpThinkingOptions? thinking;
}

class const OmpCatalogSession({required this.sessionId, required this.snapshot}) {
  final String sessionId;
  final OmpSessionConfigSnapshot snapshot;
}

class OmpProjectCatalog({
    required this.modelConfigId,
    required List<OmpCatalogModel> models,
    required this.defaultModelValue,
    required this.modeConfigId,
    required List<OmpCatalogOption> modes,
    required this.defaultModeValue,
    required Map<String, OmpThinkingOptions> thinkingByModel,
    required List<PluginCommand> commands,
    required this.completeness,
  }) {
  this : models = List.unmodifiable(models),
       modes = List.unmodifiable(modes),
       thinkingByModel = Map.unmodifiable(thinkingByModel),
       commands = List.unmodifiable(commands);

  final String modelConfigId;
  final List<OmpCatalogModel> models;
  final String? defaultModelValue;
  final String? modeConfigId;
  final List<OmpCatalogOption> modes;
  final String? defaultModeValue;
  final Map<String, OmpThinkingOptions> thinkingByModel;
  final List<PluginCommand> commands;
  final PluginSessionOptionsCompleteness completeness;
}

sealed class const OmpCatalogDiscoveryResult();

final class const OmpCatalogObserved({required this.catalog}) extends OmpCatalogDiscoveryResult {
  final OmpProjectCatalog catalog;
}

final class const OmpCatalogNoModels() extends OmpCatalogDiscoveryResult;

final class const OmpCatalogDiscoveryFailed() extends OmpCatalogDiscoveryResult;

sealed class const OmpOptionsDiscoveryResult();

final class const OmpOptionsObserved({required this.options}) extends OmpOptionsDiscoveryResult {
  final PluginSessionOptions options;
}

final class const OmpOptionsNoModels() extends OmpOptionsDiscoveryResult;

final class const OmpOptionsDiscoveryFailed() extends OmpOptionsDiscoveryResult;
