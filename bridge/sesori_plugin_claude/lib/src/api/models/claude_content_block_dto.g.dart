// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_content_block_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClaudeTextContentBlockDto _$ClaudeTextContentBlockDtoFromJson(Map json) =>
    ClaudeTextContentBlockDto(
      text: _stringOrNull(json['text']),
      $type: json['type'] as String?,
    );

ClaudeThinkingContentBlockDto _$ClaudeThinkingContentBlockDtoFromJson(
  Map json,
) => ClaudeThinkingContentBlockDto(
  thinking: _stringOrNull(json['thinking']),
  signature: _stringOrNull(json['signature']),
  $type: json['type'] as String?,
);

ClaudeRedactedThinkingContentBlockDto
_$ClaudeRedactedThinkingContentBlockDtoFromJson(Map json) =>
    ClaudeRedactedThinkingContentBlockDto($type: json['type'] as String?);

ClaudeToolUseContentBlockDto _$ClaudeToolUseContentBlockDtoFromJson(Map json) =>
    ClaudeToolUseContentBlockDto(
      id: _stringOrNull(json['id']),
      name: _stringOrNull(json['name']),
      input: json['input'],
      $type: json['type'] as String?,
    );

ClaudeToolResultContentBlockDto _$ClaudeToolResultContentBlockDtoFromJson(
  Map json,
) => ClaudeToolResultContentBlockDto(
  toolUseId: _stringOrNull(json['tool_use_id']),
  content: json['content'],
  isError: _boolOrNull(json['is_error']),
  $type: json['type'] as String?,
);

ClaudeImageContentBlockDto _$ClaudeImageContentBlockDtoFromJson(Map json) =>
    ClaudeImageContentBlockDto(
      source: _imageSourceOrNull(json['source']),
      $type: json['type'] as String?,
    );

ClaudeUnknownContentBlockDto _$ClaudeUnknownContentBlockDtoFromJson(Map json) =>
    ClaudeUnknownContentBlockDto($type: json['type'] as String?);

_ClaudeImageSourceDto _$ClaudeImageSourceDtoFromJson(Map json) =>
    _ClaudeImageSourceDto(
      type: _stringOrNull(json['type']),
      mediaType: _stringOrNull(json['media_type']),
      data: _stringOrNull(json['data']),
    );
