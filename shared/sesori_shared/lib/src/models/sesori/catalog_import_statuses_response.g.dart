// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_import_statuses_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CatalogImportStatusesResponse _$CatalogImportStatusesResponseFromJson(
  Map json,
) => _CatalogImportStatusesResponse(
  statuses: (json['statuses'] as List<dynamic>)
      .map(
        (e) =>
            CatalogImportProgress.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

Map<String, dynamic> _$CatalogImportStatusesResponseToJson(
  _CatalogImportStatusesResponse instance,
) => <String, dynamic>{
  'statuses': instance.statuses.map((e) => e.toJson()).toList(),
};
