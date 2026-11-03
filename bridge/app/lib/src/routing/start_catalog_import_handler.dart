import "package:sesori_shared/sesori_shared.dart";

import "../services/catalog_import_service.dart";
import "request_handler.dart";

class StartCatalogImportHandler({required final CatalogImportService _service})
    extends BodyRequestHandler<CatalogImportRequest, SuccessEmptyResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/plugin/import",
        fromJson: CatalogImportRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle({
    required RelayRequest request,
    required CatalogImportRequest body,
  }) async {
    try {
      _service.start(pluginId: body.pluginId, trigger: CatalogImportTrigger.rescan);
    } on CatalogImportPluginUnknownException {
      throw buildErrorResponse(request: request, status: 404, message: "plugin not found");
    } on CatalogImportPluginNotEnabledException {
      throw buildErrorResponse(request: request, status: 404, message: "plugin not selected");
    } on CatalogImportPluginUnavailableException {
      throw buildErrorResponse(request: request, status: 503, message: "plugin unavailable");
    }
    return const SuccessEmptyResponse();
  }
}
