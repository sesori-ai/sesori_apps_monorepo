// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_image_bearing_item_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodexImageGenerationItemDto _$CodexImageGenerationItemDtoFromJson(Map json) =>
    CodexImageGenerationItemDto(
      id: json['id'] as String,
      status:
          $enumDecodeNullable(
            _$CodexImageGenerationStatusEnumMap,
            json['status'],
            unknownValue: CodexImageGenerationStatus.unknown,
          ) ??
          CodexImageGenerationStatus.unknown,
      revisedPrompt: json['revisedPrompt'] as String?,
      result: json['result'] as String,
      savedPath: json['savedPath'] as String?,
      $type: json['type'] as String?,
    );

const _$CodexImageGenerationStatusEnumMap = {
  CodexImageGenerationStatus.inProgress: 'in_progress',
  CodexImageGenerationStatus.completed: 'completed',
  CodexImageGenerationStatus.failed: 'failed',
  CodexImageGenerationStatus.unknown: 'unknown',
};

CodexMcpToolCallItemDto _$CodexMcpToolCallItemDtoFromJson(Map json) =>
    CodexMcpToolCallItemDto(
      id: json['id'] as String,
      server: json['server'] as String?,
      tool: json['tool'] as String?,
      status:
          $enumDecodeNullable(
            _$CodexToolCallStatusEnumMap,
            json['status'],
            unknownValue: CodexToolCallStatus.unknown,
          ) ??
          CodexToolCallStatus.unknown,
      content: const CodexMcpResultContentConverter().fromJson(json['result']),
      error: const CodexToolErrorConverter().fromJson(json['error']),
      $type: json['type'] as String?,
    );

const _$CodexToolCallStatusEnumMap = {
  CodexToolCallStatus.inProgress: 'inProgress',
  CodexToolCallStatus.completed: 'completed',
  CodexToolCallStatus.failed: 'failed',
  CodexToolCallStatus.declined: 'declined',
  CodexToolCallStatus.unknown: 'unknown',
};

CodexDynamicToolCallItemDto _$CodexDynamicToolCallItemDtoFromJson(Map json) =>
    CodexDynamicToolCallItemDto(
      id: json['id'] as String,
      tool: const CodexToolNameConverter().fromJson(json['tool']),
      arguments: json['arguments'],
      status:
          $enumDecodeNullable(
            _$CodexToolCallStatusEnumMap,
            json['status'],
            unknownValue: CodexToolCallStatus.unknown,
          ) ??
          CodexToolCallStatus.unknown,
      content: const CodexImageBearingContentListConverter().fromJson(
        json['contentItems'],
      ),
      $type: json['type'] as String?,
    );

CodexUnknownImageBearingItemDto _$CodexUnknownImageBearingItemDtoFromJson(
  Map json,
) => CodexUnknownImageBearingItemDto($type: json['type'] as String?);

CodexMcpTextContentDto _$CodexMcpTextContentDtoFromJson(Map json) =>
    CodexMcpTextContentDto(
      text: json['text'] as String,
      $type: json['type'] as String?,
    );

CodexMcpImageContentDto _$CodexMcpImageContentDtoFromJson(Map json) =>
    CodexMcpImageContentDto(
      data: json['data'] as String,
      mimeType: json['mimeType'] as String,
      $type: json['type'] as String?,
    );

CodexDynamicTextContentDto _$CodexDynamicTextContentDtoFromJson(Map json) =>
    CodexDynamicTextContentDto(
      text: json['text'] as String,
      $type: json['type'] as String?,
    );

CodexDynamicImageContentDto _$CodexDynamicImageContentDtoFromJson(Map json) =>
    CodexDynamicImageContentDto(
      imageUrl: json['imageUrl'] as String,
      $type: json['type'] as String?,
    );

CodexDynamicAudioContentDto _$CodexDynamicAudioContentDtoFromJson(Map json) =>
    CodexDynamicAudioContentDto(
      audioUrl: json['audioUrl'] as String,
      $type: json['type'] as String?,
    );

CodexUnknownImageBearingContentDto _$CodexUnknownImageBearingContentDtoFromJson(
  Map json,
) => CodexUnknownImageBearingContentDto($type: json['type'] as String?);
