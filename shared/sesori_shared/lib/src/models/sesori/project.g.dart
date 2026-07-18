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
  path: json['path'] as String? ?? "",
  time: json['time'] == null
      ? null
      : ProjectTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  hasUnseenChanges: json['hasUnseenChanges'] as bool? ?? false,
  directoryMissing: json['directoryMissing'] as bool? ?? false,
  supportsDedicatedWorktrees:
      json['supportsDedicatedWorktrees'] as bool? ?? true,
);

Map<String, dynamic> _$ProjectToJson(_Project instance) => <String, dynamic>{
  'id': instance.id,
  'name': ?instance.name,
  'path': instance.path,
  'time': ?instance.time?.toJson(),
  'hasUnseenChanges': instance.hasUnseenChanges,
  'directoryMissing': instance.directoryMissing,
  'supportsDedicatedWorktrees': instance.supportsDedicatedWorktrees,
};

_ProjectTime _$ProjectTimeFromJson(Map json) => _ProjectTime(
  created: (json['created'] as num).toInt(),
  updated: (json['updated'] as num).toInt(),
);

Map<String, dynamic> _$ProjectTimeToJson(_ProjectTime instance) =>
    <String, dynamic>{'created': instance.created, 'updated': instance.updated};

_ProjectIdRequest _$ProjectIdRequestFromJson(Map json) =>
    _ProjectIdRequest(projectId: json['projectId'] as String);

Map<String, dynamic> _$ProjectIdRequestToJson(_ProjectIdRequest instance) =>
    <String, dynamic>{'projectId': instance.projectId};

_ProjectPathRequest _$ProjectPathRequestFromJson(Map json) =>
    _ProjectPathRequest(path: json['path'] as String);

Map<String, dynamic> _$ProjectPathRequestToJson(_ProjectPathRequest instance) =>
    <String, dynamic>{'path': instance.path};

_OpenProjectRequest _$OpenProjectRequestFromJson(Map json) =>
    _OpenProjectRequest(
      path: json['path'] as String,
      gitAction:
          $enumDecodeNullable(
            _$OpenProjectGitActionEnumMap,
            json['gitAction'],
          ) ??
          OpenProjectGitAction.openWithoutGit,
    );

Map<String, dynamic> _$OpenProjectRequestToJson(_OpenProjectRequest instance) =>
    <String, dynamic>{
      'path': instance.path,
      'gitAction': _$OpenProjectGitActionEnumMap[instance.gitAction]!,
    };

const _$OpenProjectGitActionEnumMap = {
  OpenProjectGitAction.promptIfNeeded: 'prompt_if_needed',
  OpenProjectGitAction.initializeGit: 'initialize_git',
  OpenProjectGitAction.openWithoutGit: 'open_without_git',
};
