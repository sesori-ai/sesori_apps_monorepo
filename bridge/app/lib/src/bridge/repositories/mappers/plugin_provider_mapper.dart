import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps a [PluginProvider] and its [PluginModel]s to the shared [ProviderInfo]
/// type used in relay responses.
extension PluginProviderMapper on PluginProvider {
  ProviderInfo toSharedProviderInfo() {
    return ProviderInfo(
      id: id,
      name: name,
      defaultModelID: defaultModelID,
      models: {
        for (final m in models)
          m.id: ProviderModel(
            id: m.id,
            providerID: id,
            name: m.name,
            family: m.family,
            isAvailable: m.isAvailable,
            releaseDate: m.releaseDate,
          ),
      },
    );
  }
}
