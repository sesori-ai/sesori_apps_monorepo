import "package:sesori_shared/sesori_shared.dart";

import "../repositories/provider_repository.dart";
import "request_handler.dart";

/// Handles `POST /provider` — returns providers and their models.
class GetProvidersHandler(final ProviderRepository _repository)
    extends BodyRequestHandler<PluginProjectIdRequest, ProviderListResponse> {
  this
    : super(
        HttpMethod.post,
        "/provider",
        fromJson: PluginProjectIdRequest.fromJson,
      );

  @override
  Future<ProviderListResponse> handle(
    RelayRequest request, {
    required PluginProjectIdRequest body,
  }) {
    return _repository.getProviders(
      projectId: body.projectId,
      pluginId: body.pluginId,
    );
  }
}
