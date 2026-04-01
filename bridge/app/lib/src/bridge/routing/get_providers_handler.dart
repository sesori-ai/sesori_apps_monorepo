import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /provider` — returns providers and their models from the plugin.
class GetProvidersHandler extends GetRequestHandler<ProviderListResponse> {
  final BridgePlugin _plugin;

  GetProvidersHandler(this._plugin) : super("/provider");

  @override
  Future<ProviderListResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final result = await _plugin.getProviders(connectedOnly: true);

    final providers = result.providers.map((p) {
      final models = <String, ProviderModel>{
        for (final m in p.models)
          m.id: ProviderModel(
            id: m.id,
            providerID: p.id,
            name: m.name,
            family: m.family,
            releaseDate: null,
          ),
      };
      return ProviderInfo(
        id: p.id,
        name: p.name,
        defaultModelID: p.defaultModelID,
        models: models,
      );
    }).toList();

    final response = ProviderListResponse(
      items: providers,
      connectedOnly: true,
    );

    return response;
  }
}
