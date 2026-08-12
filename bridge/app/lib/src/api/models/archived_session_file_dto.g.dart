// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archived_session_file_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ArchivedSessionFileDto _$ArchivedSessionFileDtoFromJson(Map json) =>
    _ArchivedSessionFileDto(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      archivedAt: (json['archivedAt'] as num).toInt(),
      completeness: $enumDecode(
        _$ArchivedSessionCompletenessEnumMap,
        json['completeness'],
      ),
      session: ArchivedSessionSnapshotDto.fromJson(
        Map<String, dynamic>.from(json['session'] as Map),
      ),
      messages: (json['messages'] as List<dynamic>)
          .map(
            (e) => ArchivedMessageDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$ArchivedSessionFileDtoToJson(
  _ArchivedSessionFileDto instance,
) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'archivedAt': instance.archivedAt,
  'completeness': _$ArchivedSessionCompletenessEnumMap[instance.completeness]!,
  'session': instance.session.toJson(),
  'messages': instance.messages.map((e) => e.toJson()).toList(),
};

const _$ArchivedSessionCompletenessEnumMap = {
  ArchivedSessionCompleteness.complete: 'complete',
  ArchivedSessionCompleteness.storeOnly: 'store_only',
};

_ArchivedSessionSnapshotDto _$ArchivedSessionSnapshotDtoFromJson(Map json) =>
    _ArchivedSessionSnapshotDto(
      sessionId: json['sessionId'] as String,
      backendSessionId: json['backendSessionId'] as String,
      pluginId: json['pluginId'] as String,
      projectId: json['projectId'] as String,
      parentSessionId: json['parentSessionId'] as String?,
      directory: json['directory'] as String,
      worktreePath: json['worktreePath'] as String?,
      branchName: json['branchName'] as String?,
      baseBranch: json['baseBranch'] as String?,
      baseCommit: json['baseCommit'] as String?,
      lastAgent: json['lastAgent'] as String?,
      lastAgentModel: json['lastAgentModel'] as String?,
      title: json['title'] as String?,
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
    );

Map<String, dynamic> _$ArchivedSessionSnapshotDtoToJson(
  _ArchivedSessionSnapshotDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'backendSessionId': instance.backendSessionId,
  'pluginId': instance.pluginId,
  'projectId': instance.projectId,
  'parentSessionId': ?instance.parentSessionId,
  'directory': instance.directory,
  'worktreePath': ?instance.worktreePath,
  'branchName': ?instance.branchName,
  'baseBranch': ?instance.baseBranch,
  'baseCommit': ?instance.baseCommit,
  'lastAgent': ?instance.lastAgent,
  'lastAgentModel': ?instance.lastAgentModel,
  'title': ?instance.title,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

_ArchivedMessageDto _$ArchivedMessageDtoFromJson(Map json) =>
    _ArchivedMessageDto(
      seq: (json['seq'] as num).toInt(),
      info: Message.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
      parts: (json['parts'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );

Map<String, dynamic> _$ArchivedMessageDtoToJson(_ArchivedMessageDto instance) =>
    <String, dynamic>{
      'seq': instance.seq,
      'info': instance.info.toJson(),
      'parts': instance.parts,
    };
