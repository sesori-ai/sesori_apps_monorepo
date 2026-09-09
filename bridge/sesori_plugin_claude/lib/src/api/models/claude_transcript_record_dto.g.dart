// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_transcript_record_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaudeTranscriptRecordDto _$ClaudeTranscriptRecordDtoFromJson(Map json) => _ClaudeTranscriptRecordDto(
  type: _stringOrNull(json['type']),
  sessionId: _stringOrNull(json['sessionId']),
  cwd: _stringOrNull(json['cwd']),
  timestamp: _timestampOrNull(json['timestamp']),
  isSidechain: _boolOrNull(json['isSidechain']),
  agentId: _stringOrNull(json['agentId']),
  gitBranch: _stringOrNull(json['gitBranch']),
  version: _stringOrNull(json['version']),
  aiTitle: _stringOrNull(json['aiTitle']),
  uuid: _stringOrNull(json['uuid']),
  isMeta: _boolOrNull(json['isMeta']),
  isVisibleInTranscriptOnly: _boolOrNull(json['isVisibleInTranscriptOnly']),
  isApiErrorMessage: _boolOrNull(json['isApiErrorMessage']),
  apiErrorStatus: _intOrNull(json['apiErrorStatus']),
  effort: _stringOrNull(json['effort']),
  message: _messageOrNull(json['message']),
  toolUseResult: ClaudeToolUseResult.parse(json['toolUseResult']),
  originKind: _originKindOrNull(json['origin']),
);

_ClaudeTranscriptMessageDto _$ClaudeTranscriptMessageDtoFromJson(Map json) => _ClaudeTranscriptMessageDto(
  id: _stringOrNull(json['id']),
  model: _stringOrNull(json['model']),
  content: json['content'],
);
