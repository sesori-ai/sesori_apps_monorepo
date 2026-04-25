import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePlugin;
import "package:sesori_shared/sesori_shared.dart" show ProviderListResponse;

import "mappers/plugin_provider_mapper.dart";

/// Wraps [BridgePlugin.getProviders] and maps plugin models to shared types.
class ProviderRepository {
  final BridgePlugin _plugin;

  ProviderRepository({required BridgePlugin plugin}) : _plugin = plugin;

  Future<ProviderListResponse> getProviders({String? directory}) async {
    final result = await _plugin.getProviders(connectedOnly: true, directory: directory);
    final providers = result.providers.map((p) => p.toSharedProviderInfo()).toList();
    return ProviderListResponse(items: providers, connectedOnly: true);
  }
}
