import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

const String _connectedOnlyParam = "connectedOnly";

/// Handles `GET /provider` — returns providers and their models from the plugin.
class GetProvidersHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetProvidersHandler(this._plugin) : super(HttpMethod.get, "/provider");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    // Default to true if not specified
    final connectedOnly = !(queryParams[_connectedOnlyParam]?.toLowerCase() == "false");

    final result = await _plugin.getProviders(connectedOnly: connectedOnly);

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
      connectedOnly: connectedOnly,
    );

    return buildOkJsonResponse(request, jsonEncode(response.toJson()));
  }
}
