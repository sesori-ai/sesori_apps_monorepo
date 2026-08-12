import "package:sesori_shared/sesori_shared.dart";

final class PluginDiscoverySnapshot({
    required this.bridgeId,
    required this.supportsSessionOptions,
    required List<PluginMetadata> plugins,
  }) {
  this : plugins = List.unmodifiable(plugins);

  final String? bridgeId;
  final bool supportsSessionOptions;
  final List<PluginMetadata> plugins;
}
