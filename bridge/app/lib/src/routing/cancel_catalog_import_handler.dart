import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/catalog_import_service.dart";

class CancelCatalogImportHandler extends BodyRequestHandler<CatalogImportRequest, SuccessEmptyResponse> {
  CancelCatalogImportHandler({required CatalogImportService service})
    : _service = service,
      super(
        HttpMethod.delete,
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
      _service.cancel(pluginId: body.pluginId);
    } on CatalogImportPluginNotSelectedException {
      throw buildErrorResponse(request, 404, "plugin not selected");
    }
    return const SuccessEmptyResponse();
  }
}
