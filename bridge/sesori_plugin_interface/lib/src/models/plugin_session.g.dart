// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginSessionToJson(_PluginSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'projectID': instance.projectID,
      'directory': instance.directory,
      'parentID': ?instance.parentID,
      'title': ?instance.title,
      'time': ?instance.time?.toJson(),
    };

Map<String, dynamic> _$PluginSessionTimeToJson(_PluginSessionTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'updated': instance.updated,
      'archived': ?instance.archived,
    };
