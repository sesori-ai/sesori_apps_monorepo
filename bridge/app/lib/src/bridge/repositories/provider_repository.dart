import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;
import "package:sesori_shared/sesori_shared.dart" show ProviderListResponse;

import "mappers/plugin_provider_mapper.dart";

/// Wraps [BridgePluginApi.getProviders] and maps plugin models to shared types.
class ProviderRepository {
  final BridgePluginApi _plugin;

  ProviderRepository({required BridgePluginApi plugin}) : _plugin = plugin;

  Future<ProviderListResponse> getProviders({required String projectId}) async {
    final result = await _plugin.getProviders(projectId: projectId);
    final providers = result.providers.map((p) => p.toSharedProviderInfo()).toList();
    return ProviderListResponse(items: providers, connectedOnly: true);
  }
}
