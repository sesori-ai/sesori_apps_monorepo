import "package:sesori_shared/sesori_shared.dart";

final class PluginDiscoverySnapshot({
  required final String? bridgeId,
  required final bool supportsSessionOptions,

  /// Whether the bridge saves prompt files that are not inline images, for
  /// every plugin it runs.
  required final bool supportsFileUploads,

  /// Whether the bridge has the side-question routes.
  required final bool supportsSideQuestions,
  required List<PluginMetadata> plugins,
}) {
  final List<PluginMetadata> plugins = List.unmodifiable(plugins);
}
