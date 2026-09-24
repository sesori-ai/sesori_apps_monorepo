import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Native capabilities retained with the options from the same catalog probe.
final class const PiCatalogSnapshot({
  required final PluginSessionOptions options,
  required final Set<({String providerID, String modelID})> nonReasoningModels,
});
