import "package:sesori_shared/sesori_shared.dart";

import "../repositories/provider_repository.dart";
import "request_handler.dart";

/// Handles `GET /provider` — returns providers and their models.
class GetProvidersHandler extends GetRequestHandler<ProviderListResponse> {
  final ProviderRepository _repository;

  GetProvidersHandler(this._repository) : super("/provider");

  @override
  Future<ProviderListResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) {
    return _repository.getProviders(
      directory: findHeader(request.headers, "x-opencode-directory"),
      projectId: queryParams["projectId"],
    );
  }
}
