import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/catalog_import_service.dart";

class StartCatalogImportHandler({required CatalogImportService service}) extends BodyRequestHandler<CatalogImportRequest, SuccessEmptyResponse> {
  this
    : _service = service,
      super(
        HttpMethod.post,
        "/plugin/import",
        fromJson: CatalogImportRequest.fromJson,
      );

  final CatalogImportService _service;

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required CatalogImportRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      _service.start(pluginId: body.pluginId, trigger: CatalogImportTrigger.explicit);
    } on CatalogImportPluginUnknownException {
      throw buildErrorResponse(request, 404, "plugin not found");
    } on CatalogImportPluginNotEnabledException {
      throw buildErrorResponse(request, 404, "plugin not selected");
    } on CatalogImportPluginUnavailableException {
      throw buildErrorResponse(request, 503, "plugin unavailable");
    }
    return const SuccessEmptyResponse();
  }
}
