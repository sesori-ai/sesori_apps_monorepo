// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_transcript_record_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaudeTranscriptRecordDto _$ClaudeTranscriptRecordDtoFromJson(Map json) =>
    _ClaudeTranscriptRecordDto(
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
      isCompactSummary: _boolOrNull(json['isCompactSummary']),
      isApiErrorMessage: _boolOrNull(json['isApiErrorMessage']),
      apiErrorStatus: _intOrNull(json['apiErrorStatus']),
      effort: _stringOrNull(json['effort']),
      message: _messageOrNull(json['message']),
      toolUseResult: ClaudeToolUseResult.parse(json['toolUseResult']),
      originKind: _originKind(json['origin']),
      attachment: _attachmentOrNull(json['attachment']),
    );

_ClaudeTranscriptAttachmentDto _$ClaudeTranscriptAttachmentDtoFromJson(
  Map json,
) => _ClaudeTranscriptAttachmentDto(
  type: _stringOrNull(json['type']),
  prompt: json['prompt'],
  commandMode: _stringOrNull(json['commandMode']),
  sourceUuid: _stringOrNull(json['source_uuid']),
  isMeta: _boolOrNull(json['isMeta']),
  originKind: _originKind(json['origin']),
);

_ClaudeTranscriptMessageDto _$ClaudeTranscriptMessageDtoFromJson(Map json) =>
    _ClaudeTranscriptMessageDto(
      id: _stringOrNull(json['id']),
      model: _stringOrNull(json['model']),
      content: json['content'],
    );
