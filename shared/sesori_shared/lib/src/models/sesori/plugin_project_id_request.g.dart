// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_project_id_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PluginProjectIdRequest _$PluginProjectIdRequestFromJson(Map json) =>
    _PluginProjectIdRequest(
      projectId: json['projectId'] as String,
      pluginId: json['pluginId'] as String? ?? legacyMissingPluginId,
    );

Map<String, dynamic> _$PluginProjectIdRequestToJson(
  _PluginProjectIdRequest instance,
) => <String, dynamic>{
  'projectId': instance.projectId,
  'pluginId': instance.pluginId,
};
