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
      gitBranch: _stringOrNull(json['gitBranch']),
      version: _stringOrNull(json['version']),
      aiTitle: _stringOrNull(json['aiTitle']),
    );
