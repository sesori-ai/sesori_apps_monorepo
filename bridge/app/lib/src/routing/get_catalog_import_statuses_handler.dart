import "package:sesori_shared/sesori_shared.dart";

import "../services/catalog_import_service.dart";
import "request_handler.dart";

class GetCatalogImportStatusesHandler({required final CatalogImportService _service})
    extends GetRequestHandler<CatalogImportStatusesResponse> {
  this : super("/plugin/import");

  @override
  Future<CatalogImportStatusesResponse> handle(
    RelayRequest request,
  ) async {
    return CatalogImportStatusesResponse(statuses: _service.latestStatuses);
  }
}
