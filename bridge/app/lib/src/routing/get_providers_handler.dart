import "package:sesori_shared/sesori_shared.dart";

import "../repositories/provider_repository.dart";
import "request_handler.dart";

/// Handles `POST /provider` — returns providers and their models.
class GetProvidersHandler({required final ProviderRepository _repository})
    extends BodyRequestHandler<PluginProjectIdRequest, ProviderListResponse> {
  this
    : super(
        method: HttpMethod.post,
        // COMPATIBILITY 2026-11-03 (v1.12.0): Apps older than v1.7.1 load providers here; later apps call it only
        // on bridges without /session/options. Remove once public apps older than v1.7.1 are unsupported.
        path: "/provider",
        fromJson: PluginProjectIdRequest.fromJson,
      );

  @override
  Future<ProviderListResponse> handle({
    required RelayRequest request,
    required PluginProjectIdRequest body,
  }) {
    return _repository.getProviders(
      projectId: body.projectId,
      pluginId: body.pluginId,
    );
  }
}
