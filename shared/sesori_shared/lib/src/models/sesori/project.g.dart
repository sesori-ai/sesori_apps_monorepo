// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Projects _$ProjectsFromJson(Map json) => _Projects(
  data: (json['data'] as List<dynamic>)
      .map((e) => Project.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

Map<String, dynamic> _$ProjectsToJson(_Projects instance) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
};

_Project _$ProjectFromJson(Map json) => _Project(
  id: json['id'] as String,
  name: json['name'] as String?,
  time: json['time'] == null
      ? null
      : ProjectTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
);

Map<String, dynamic> _$ProjectToJson(_Project instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'time': instance.time?.toJson(),
};

_ProjectTime _$ProjectTimeFromJson(Map json) => _ProjectTime(
  created: (json['created'] as num).toInt(),
  updated: (json['updated'] as num).toInt(),
  initialized: (json['initialized'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProjectTimeToJson(_ProjectTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'updated': instance.updated,
      'initialized': instance.initialized,
    };

_ProjectIdRequest _$ProjectIdRequestFromJson(Map json) =>
    _ProjectIdRequest(projectId: json['projectId'] as String);

Map<String, dynamic> _$ProjectIdRequestToJson(_ProjectIdRequest instance) =>
    <String, dynamic>{'projectId': instance.projectId};

_ProjectPathRequest _$ProjectPathRequestFromJson(Map json) =>
    _ProjectPathRequest(path: json['path'] as String);

Map<String, dynamic> _$ProjectPathRequestToJson(_ProjectPathRequest instance) =>
    <String, dynamic>{'path': instance.path};
