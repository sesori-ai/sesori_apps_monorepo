// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_import_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CatalogImportNewItems _$CatalogImportNewItemsFromJson(Map json) =>
    _CatalogImportNewItems(
      projects: (json['projects'] as num).toInt(),
      sessions: (json['sessions'] as num).toInt(),
    );

Map<String, dynamic> _$CatalogImportNewItemsToJson(
  _CatalogImportNewItems instance,
) => <String, dynamic>{
  'projects': instance.projects,
  'sessions': instance.sessions,
};

CatalogImportEnumerating _$CatalogImportEnumeratingFromJson(Map json) =>
    CatalogImportEnumerating(
      pluginId: json['pluginId'] as String,
      projectsSeen: (json['projectsSeen'] as num).toInt(),
      sessionsSeen: (json['sessionsSeen'] as num).toInt(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CatalogImportEnumeratingToJson(
  CatalogImportEnumerating instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'projectsSeen': instance.projectsSeen,
  'sessionsSeen': instance.sessionsSeen,
  'type': instance.$type,
};

CatalogImportCommitting _$CatalogImportCommittingFromJson(Map json) =>
    CatalogImportCommitting(
      pluginId: json['pluginId'] as String,
      projectsSeen: (json['projectsSeen'] as num).toInt(),
      sessionsSeen: (json['sessionsSeen'] as num).toInt(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CatalogImportCommittingToJson(
  CatalogImportCommitting instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'projectsSeen': instance.projectsSeen,
  'sessionsSeen': instance.sessionsSeen,
  'type': instance.$type,
};

CatalogImportCompleted _$CatalogImportCompletedFromJson(Map json) =>
    CatalogImportCompleted(
      pluginId: json['pluginId'] as String,
      projectsImported: (json['projectsImported'] as num).toInt(),
      sessionsImported: (json['sessionsImported'] as num).toInt(),
      completedAt: (json['completedAt'] as num).toInt(),
      newItems: json['newItems'] == null
          ? null
          : CatalogImportNewItems.fromJson(
              Map<String, dynamic>.from(json['newItems'] as Map),
            ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CatalogImportCompletedToJson(
  CatalogImportCompleted instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'projectsImported': instance.projectsImported,
  'sessionsImported': instance.sessionsImported,
  'completedAt': instance.completedAt,
  'newItems': ?instance.newItems?.toJson(),
  'type': instance.$type,
};

CatalogImportCancelled _$CatalogImportCancelledFromJson(Map json) =>
    CatalogImportCancelled(
      pluginId: json['pluginId'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CatalogImportCancelledToJson(
  CatalogImportCancelled instance,
) => <String, dynamic>{'pluginId': instance.pluginId, 'type': instance.$type};

CatalogImportFailed _$CatalogImportFailedFromJson(Map json) =>
    CatalogImportFailed(
      pluginId: json['pluginId'] as String,
      message: json['message'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CatalogImportFailedToJson(
  CatalogImportFailed instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'message': instance.message,
  'type': instance.$type,
};
