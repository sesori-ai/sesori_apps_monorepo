import "package:freezed_annotation/freezed_annotation.dart";

part "catalog_import_request.freezed.dart";
part "catalog_import_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class CatalogImportRequest with _$CatalogImportRequest {
  const factory CatalogImportRequest({
    required String pluginId,
  }) = _CatalogImportRequest;

  factory CatalogImportRequest.fromJson(Map<String, dynamic> json) => _$CatalogImportRequestFromJson(json);
}
