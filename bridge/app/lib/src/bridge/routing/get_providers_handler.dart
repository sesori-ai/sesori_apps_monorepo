import "package:sesori_shared/sesori_shared.dart";

import "../repositories/provider_repository.dart";
import "request_handler.dart";

/// Handles `POST /provider` — returns providers and their models.
class GetProvidersHandler extends BodyRequestHandler<ProjectIdRequest, ProviderListResponse> {
  final ProviderRepository _repository;

  GetProvidersHandler(this._repository)
    : super(
        HttpMethod.post,
        "/provider",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<ProviderListResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) {
    return _repository.getProviders(projectId: body.projectId);
  }
}
