import "package:sesori_shared/sesori_shared.dart";

final class PluginDiscoverySnapshot {
  PluginDiscoverySnapshot({
    required this.bridgeId,
    required this.supportsSessionOptions,
    required List<PluginMetadata> plugins,
  }) : plugins = List.unmodifiable(plugins);

  final String? bridgeId;
  final bool supportsSessionOptions;
  final List<PluginMetadata> plugins;
}
