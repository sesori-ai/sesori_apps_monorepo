import "package:sesori_shared/sesori_shared.dart";

import "../repositories/provider_repository.dart";
import "request_handler.dart";

/// Handles `POST /provider` — returns providers and their models.
class GetProvidersHandler extends BodyRequestHandler<PluginProjectIdRequest, ProviderListResponse> {
  final ProviderRepository _repository;

  GetProvidersHandler(this._repository)
    : super(
        HttpMethod.post,
        "/provider",
        fromJson: PluginProjectIdRequest.fromJson,
      );

  @override
  Future<ProviderListResponse> handle(
    RelayRequest request, {
    required PluginProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) {
    return _repository.getProviders(
      projectId: body.projectId,
      pluginId: body.pluginId == legacyMissingPluginId ? _repository.pluginId : body.pluginId,
    );
  }
}
