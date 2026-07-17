import "package:freezed_annotation/freezed_annotation.dart";

import "catalog_import_progress.dart";

part "catalog_import_statuses_response.freezed.dart";
part "catalog_import_statuses_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class CatalogImportStatusesResponse with _$CatalogImportStatusesResponse {
  const factory CatalogImportStatusesResponse({
    required List<CatalogImportProgress> statuses,
  }) = _CatalogImportStatusesResponse;

  factory CatalogImportStatusesResponse.fromJson(Map<String, dynamic> json) =>
      _$CatalogImportStatusesResponseFromJson(json);
}
