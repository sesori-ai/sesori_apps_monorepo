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

CodexRolloutSessionMetadataLineDto _$CodexRolloutSessionMetadataLineDtoFromJson(
  Map json,
) => CodexRolloutSessionMetadataLineDto(
  timestamp: json['timestamp'] as String?,
  payload: CodexRolloutSessionMetadataPayloadDto.fromJson(
    Map<String, dynamic>.from(json['payload'] as Map),
  ),
  $type: json['type'] as String?,
);

CodexRolloutTurnContextLineDto _$CodexRolloutTurnContextLineDtoFromJson(
  Map json,
) => CodexRolloutTurnContextLineDto(
  timestamp: json['timestamp'] as String?,
  payload: CodexRolloutTurnContextPayloadDto.fromJson(
    Map<String, dynamic>.from(json['payload'] as Map),
  ),
  $type: json['type'] as String?,
);

CodexRolloutResponseItemLineDto _$CodexRolloutResponseItemLineDtoFromJson(
  Map json,
) => CodexRolloutResponseItemLineDto(
  timestamp: json['timestamp'] as String?,
  payload: CodexRolloutResponseItemDto.fromJson(
    Map<String, dynamic>.from(json['payload'] as Map),
  ),
  $type: json['type'] as String?,
);

CodexRolloutCompactedLineDto _$CodexRolloutCompactedLineDtoFromJson(Map json) =>
    CodexRolloutCompactedLineDto(
      timestamp: json['timestamp'] as String?,
      $type: json['type'] as String?,
    );

CodexRolloutUnknownLineDto _$CodexRolloutUnknownLineDtoFromJson(Map json) =>
    CodexRolloutUnknownLineDto(
      timestamp: json['timestamp'] as String?,
      $type: json['type'] as String?,
    );

_CodexRolloutSessionMetadataPayloadDto
_$CodexRolloutSessionMetadataPayloadDtoFromJson(Map json) =>
    _CodexRolloutSessionMetadataPayloadDto(
      id: json['id'] as String?,
      cwd: json['cwd'] as String?,
      timestamp: json['timestamp'] as String?,
      modelProvider: json['model_provider'] as String?,
      cliVersion: json['cli_version'] as String?,
    );

_CodexRolloutTurnContextPayloadDto _$CodexRolloutTurnContextPayloadDtoFromJson(
  Map json,
) => _CodexRolloutTurnContextPayloadDto(model: json['model'] as String?);

CodexRolloutMessageDto _$CodexRolloutMessageDtoFromJson(Map json) =>
    CodexRolloutMessageDto(
      id: json['id'] as String?,
      role: $enumDecode(
        _$CodexRolloutRoleEnumMap,
        json['role'],
        unknownValue: CodexRolloutRole.unknown,
      ),
      content: const CodexRolloutContentListConverter().fromJson(
        json['content'],
      ),
      $type: json['type'] as String?,
    );

const _$CodexRolloutRoleEnumMap = {
  CodexRolloutRole.user: 'user',
  CodexRolloutRole.assistant: 'assistant',
  CodexRolloutRole.unknown: 'unknown',
};

CodexRolloutReasoningDto _$CodexRolloutReasoningDtoFromJson(Map json) =>
    CodexRolloutReasoningDto(
      id: json['id'] as String?,
      summary: const CodexRolloutContentListConverter().fromJson(
        json['summary'],
      ),
      $type: json['type'] as String?,
    );

CodexRolloutFunctionCallDto _$CodexRolloutFunctionCallDtoFromJson(Map json) =>
    CodexRolloutFunctionCallDto(
      id: json['id'] as String?,
      callId: json['call_id'] as String,
      name: json['name'] as String,
      arguments: json['arguments'] as String,
      $type: json['type'] as String?,
    );

CodexRolloutFunctionCallOutputDto _$CodexRolloutFunctionCallOutputDtoFromJson(
  Map json,
) => CodexRolloutFunctionCallOutputDto(
  callId: json['call_id'] as String,
  output: const CodexRolloutOutputConverter().fromJson(json['output']),
  $type: json['type'] as String?,
);

CodexRolloutCustomToolCallDto _$CodexRolloutCustomToolCallDtoFromJson(
  Map json,
) => CodexRolloutCustomToolCallDto(
  id: json['id'] as String?,
  callId: json['call_id'] as String,
  name: json['name'] as String,
  input: json['input'] as String,
  $type: json['type'] as String?,
);

CodexRolloutCustomToolCallOutputDto
_$CodexRolloutCustomToolCallOutputDtoFromJson(Map json) =>
    CodexRolloutCustomToolCallOutputDto(
      callId: json['call_id'] as String,
      output: const CodexRolloutOutputConverter().fromJson(json['output']),
      $type: json['type'] as String?,
    );

CodexRolloutWebSearchCallDto _$CodexRolloutWebSearchCallDtoFromJson(Map json) =>
    CodexRolloutWebSearchCallDto(
      id: json['id'] as String?,
      action: json['action'] == null
          ? null
          : CodexRolloutActionDto.fromJson(
              Map<String, dynamic>.from(json['action'] as Map),
            ),
      $type: json['type'] as String?,
    );

CodexRolloutUnknownResponseItemDto _$CodexRolloutUnknownResponseItemDtoFromJson(
  Map json,
) => CodexRolloutUnknownResponseItemDto($type: json['type'] as String?);

CodexRolloutInputTextDto _$CodexRolloutInputTextDtoFromJson(Map json) =>
    CodexRolloutInputTextDto(
      text: json['text'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CodexRolloutInputTextDtoToJson(
  CodexRolloutInputTextDto instance,
) => <String, dynamic>{'text': instance.text, 'type': instance.$type};

CodexRolloutOutputTextDto _$CodexRolloutOutputTextDtoFromJson(Map json) =>
    CodexRolloutOutputTextDto(
      text: json['text'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CodexRolloutOutputTextDtoToJson(
  CodexRolloutOutputTextDto instance,
) => <String, dynamic>{'text': instance.text, 'type': instance.$type};

CodexRolloutSummaryTextDto _$CodexRolloutSummaryTextDtoFromJson(Map json) =>
    CodexRolloutSummaryTextDto(
      text: json['text'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CodexRolloutSummaryTextDtoToJson(
  CodexRolloutSummaryTextDto instance,
) => <String, dynamic>{'text': instance.text, 'type': instance.$type};

CodexRolloutInputImageDto _$CodexRolloutInputImageDtoFromJson(Map json) =>
    CodexRolloutInputImageDto(
      imageUrl: json['image_url'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$CodexRolloutInputImageDtoToJson(
  CodexRolloutInputImageDto instance,
) => <String, dynamic>{'image_url': instance.imageUrl, 'type': instance.$type};

CodexRolloutUnknownContentDto _$CodexRolloutUnknownContentDtoFromJson(
  Map json,
) => CodexRolloutUnknownContentDto($type: json['type'] as String?);

Map<String, dynamic> _$CodexRolloutUnknownContentDtoToJson(
  CodexRolloutUnknownContentDto instance,
) => <String, dynamic>{'type': instance.$type};

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
