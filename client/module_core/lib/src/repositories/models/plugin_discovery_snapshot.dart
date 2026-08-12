import "package:sesori_shared/sesori_shared.dart";

final class PluginDiscoverySnapshot({
  required final String? bridgeId,
  required final bool supportsSessionOptions,
  required List<PluginMetadata> plugins,
}) {
  final List<PluginMetadata> plugins = List.unmodifiable(plugins);
}
