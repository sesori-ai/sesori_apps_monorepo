// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginProjectToJson(_PluginProject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'directory': instance.directory,
      'name': ?instance.name,
      'activity': ?instance.activity?.toJson(),
    };

Map<String, dynamic> _$PluginProjectActivityToJson(
  _PluginProjectActivity instance,
) => <String, dynamic>{
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};
