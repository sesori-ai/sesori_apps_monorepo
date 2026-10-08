// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_compact_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaudeCompactMetadata _$ClaudeCompactMetadataFromJson(Map json) =>
    _ClaudeCompactMetadata(
      trigger: _triggerOrNull(json['trigger']),
      preTokens: _intOrNull(_readPreTokens(json, 'preTokens')),
      postTokens: _intOrNull(_readPostTokens(json, 'postTokens')),
    );
