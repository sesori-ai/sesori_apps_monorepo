// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Project _$ProjectFromJson(Map json) => _Project(
  id: json['id'] as String,
  worktree: json['worktree'] as String,
  name: json['name'] as String?,
  time: json['time'] == null ? null : ProjectTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
);

Map<String, dynamic> _$ProjectToJson(_Project instance) => <String, dynamic>{
  'id': instance.id,
  'worktree': instance.worktree,
  'name': instance.name,
  'time': instance.time?.toJson(),
};

_ProjectTime _$ProjectTimeFromJson(Map json) => _ProjectTime(
  created: (json['created'] as num).toInt(),
  updated: (json['updated'] as num).toInt(),
  initialized: (json['initialized'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProjectTimeToJson(_ProjectTime instance) => <String, dynamic>{
  'created': instance.created,
  'updated': instance.updated,
  'initialized': instance.initialized,
};
