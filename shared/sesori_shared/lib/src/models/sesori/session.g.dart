// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Session _$SessionFromJson(Map json) => _Session(
  id: json['id'] as String,
  projectID: json['projectID'] as String,
  directory: json['directory'] as String,
  parentID: json['parentID'] as String?,
  title: json['title'] as String?,
  time: json['time'] == null
      ? null
      : SessionTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  summary: json['summary'] == null
      ? null
      : SessionSummary.fromJson(
          Map<String, dynamic>.from(json['summary'] as Map),
        ),
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'id': instance.id,
  'projectID': instance.projectID,
  'directory': instance.directory,
  'parentID': instance.parentID,
  'title': instance.title,
  'time': instance.time?.toJson(),
  'summary': instance.summary?.toJson(),
};

_SessionTime _$SessionTimeFromJson(Map json) => _SessionTime(
  created: (json['created'] as num).toInt(),
  updated: (json['updated'] as num).toInt(),
  archived: (json['archived'] as num?)?.toInt(),
);

Map<String, dynamic> _$SessionTimeToJson(_SessionTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'updated': instance.updated,
      'archived': instance.archived,
    };

_SessionSummary _$SessionSummaryFromJson(Map json) => _SessionSummary(
  additions: (json['additions'] as num?)?.toInt() ?? 0,
  deletions: (json['deletions'] as num?)?.toInt() ?? 0,
  files: (json['files'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SessionSummaryToJson(_SessionSummary instance) =>
    <String, dynamic>{
      'additions': instance.additions,
      'deletions': instance.deletions,
      'files': instance.files,
    };

_GlobalSession _$GlobalSessionFromJson(Map json) => _GlobalSession(
  id: json['id'] as String,
  projectID: json['projectID'] as String,
  directory: json['directory'] as String,
  parentID: json['parentID'] as String?,
  title: json['title'] as String?,
  time: json['time'] == null
      ? null
      : SessionTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  summary: json['summary'] == null
      ? null
      : SessionSummary.fromJson(
          Map<String, dynamic>.from(json['summary'] as Map),
        ),
  project: json['project'] == null
      ? null
      : SessionProject.fromJson(
          Map<String, dynamic>.from(json['project'] as Map),
        ),
);

Map<String, dynamic> _$GlobalSessionToJson(_GlobalSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'projectID': instance.projectID,
      'directory': instance.directory,
      'parentID': instance.parentID,
      'title': instance.title,
      'time': instance.time?.toJson(),
      'summary': instance.summary?.toJson(),
      'project': instance.project?.toJson(),
    };

_SessionProject _$SessionProjectFromJson(Map json) => _SessionProject(
  id: json['id'] as String,
  name: json['name'] as String?,
  worktree: json['worktree'] as String,
);

Map<String, dynamic> _$SessionProjectToJson(_SessionProject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'worktree': instance.worktree,
    };
