import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/catalog_import_service.dart";

class GetCatalogImportStatusesHandler({required CatalogImportService service}) extends GetRequestHandler<CatalogImportStatusesResponse> {
  this
    : _service = service,
      super("/plugin/import");

  final CatalogImportService _service;

  @override
  Future<CatalogImportStatusesResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return CatalogImportStatusesResponse(statuses: _service.latestStatuses);
  }
}
