import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/catalog_import_service.dart";

class StartCatalogImportHandler extends BodyRequestHandler<CatalogImportRequest, SuccessEmptyResponse> {
  StartCatalogImportHandler({required CatalogImportService service})
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
    } on CatalogImportPluginNotSelectedException {
      throw buildErrorResponse(request, 404, "plugin not selected");
    }
    return const SuccessEmptyResponse();
  }
}
