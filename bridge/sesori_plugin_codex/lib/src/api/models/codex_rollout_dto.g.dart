// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_rollout_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexSessionIndexEntryDto _$CodexSessionIndexEntryDtoFromJson(Map json) =>
    _CodexSessionIndexEntryDto(
      id: json['id'] as String?,
      threadName: json['thread_name'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

_CodexRolloutLineDto _$CodexRolloutLineDtoFromJson(Map json) =>
    _CodexRolloutLineDto(
      timestamp: json['timestamp'] as String?,
      type: $enumDecodeNullable(
        _$CodexRolloutLineTypeEnumMap,
        json['type'],
        unknownValue: CodexRolloutLineType.unknown,
      ),
      payload: json['payload'] == null
          ? null
          : CodexRolloutPayloadDto.fromJson(
              Map<String, dynamic>.from(json['payload'] as Map),
            ),
    );

const _$CodexRolloutLineTypeEnumMap = {
  CodexRolloutLineType.sessionMeta: 'session_meta',
  CodexRolloutLineType.turnContext: 'turn_context',
  CodexRolloutLineType.responseItem: 'response_item',
  CodexRolloutLineType.unknown: 'unknown',
};

_CodexRolloutPayloadDto _$CodexRolloutPayloadDtoFromJson(Map json) =>
    _CodexRolloutPayloadDto(
      id: json['id'] as String?,
      cwd: json['cwd'] as String?,
      timestamp: json['timestamp'] as String?,
      modelProvider: json['model_provider'] as String?,
      cliVersion: json['cli_version'] as String?,
      model: json['model'] as String?,
      type: $enumDecodeNullable(
        _$CodexRolloutPayloadTypeEnumMap,
        json['type'],
        unknownValue: CodexRolloutPayloadType.unknown,
      ),
      role: $enumDecodeNullable(
        _$CodexRolloutRoleEnumMap,
        json['role'],
        unknownValue: CodexRolloutRole.unknown,
      ),
      content: const CodexRolloutContentListConverter().fromJson(
        json['content'],
      ),
      summary: const CodexRolloutSummaryConverter().fromJson(json['summary']),
      callId: json['call_id'] as String?,
      name: json['name'] as String?,
      arguments: json['arguments'] as String?,
      input: json['input'] as String?,
      output: const CodexRolloutOutputConverter().fromJson(json['output']),
      action: json['action'] == null
          ? null
          : CodexRolloutActionDto.fromJson(
              Map<String, dynamic>.from(json['action'] as Map),
            ),
    );

const _$CodexRolloutPayloadTypeEnumMap = {
  CodexRolloutPayloadType.message: 'message',
  CodexRolloutPayloadType.reasoning: 'reasoning',
  CodexRolloutPayloadType.functionCall: 'function_call',
  CodexRolloutPayloadType.functionCallOutput: 'function_call_output',
  CodexRolloutPayloadType.customToolCall: 'custom_tool_call',
  CodexRolloutPayloadType.customToolCallOutput: 'custom_tool_call_output',
  CodexRolloutPayloadType.webSearchCall: 'web_search_call',
  CodexRolloutPayloadType.unknown: 'unknown',
};

const _$CodexRolloutRoleEnumMap = {
  CodexRolloutRole.user: 'user',
  CodexRolloutRole.assistant: 'assistant',
  CodexRolloutRole.unknown: 'unknown',
};

_CodexRolloutContentDto _$CodexRolloutContentDtoFromJson(Map json) =>
    _CodexRolloutContentDto(
      type: $enumDecodeNullable(
        _$CodexRolloutContentTypeEnumMap,
        json['type'],
        unknownValue: CodexRolloutContentType.unknown,
      ),
      text: json['text'] as String?,
    );

const _$CodexRolloutContentTypeEnumMap = {
  CodexRolloutContentType.inputText: 'input_text',
  CodexRolloutContentType.outputText: 'output_text',
  CodexRolloutContentType.summaryText: 'summary_text',
  CodexRolloutContentType.unknown: 'unknown',
};

_CodexRolloutActionDto _$CodexRolloutActionDtoFromJson(Map json) =>
    _CodexRolloutActionDto(query: json['query'] as String?);

_CodexToolArgumentsDto _$CodexToolArgumentsDtoFromJson(Map json) =>
    _CodexToolArgumentsDto(
      cmd: json['cmd'],
      command: json['command'],
      path: json['path'],
      filePath: json['file_path'],
      query: json['query'],
    );
