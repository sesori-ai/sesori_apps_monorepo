import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

part "codex_rollout_dto.freezed.dart";
part "codex_rollout_dto.g.dart";

enum CodexRolloutRole {
  user,
  assistant,
  unknown,
}

enum CodexRolloutImageGenerationStatus {
  @JsonValue("in_progress")
  inProgress,
  completed,
  failed,
  unknown,
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSessionIndexEntryDto with _$CodexSessionIndexEntryDto {
  const factory CodexSessionIndexEntryDto({
    required String? id,
    @JsonKey(name: "thread_name") required String? threadName,
    @JsonKey(name: "updated_at") required String? updatedAt,
  }) = _CodexSessionIndexEntryDto;

  factory CodexSessionIndexEntryDto.fromJson(Map<String, dynamic> json) => _$CodexSessionIndexEntryDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexRolloutLineDto with _$CodexRolloutLineDto {
  @FreezedUnionValue("session_meta")
  const factory CodexRolloutLineDto.sessionMetadata({
    required String? timestamp,
    required CodexRolloutSessionMetadataPayloadDto payload,
  }) = CodexRolloutSessionMetadataLineDto;

  @FreezedUnionValue("turn_context")
  const factory CodexRolloutLineDto.turnContext({
    required String? timestamp,
    required CodexRolloutTurnContextPayloadDto payload,
  }) = CodexRolloutTurnContextLineDto;

  @FreezedUnionValue("response_item")
  const factory CodexRolloutLineDto.responseItem({
    required String? timestamp,
    required CodexRolloutResponseItemDto payload,
  }) = CodexRolloutResponseItemLineDto;

  @FreezedUnionValue("compacted")
  const factory CodexRolloutLineDto.compacted({
    required String? timestamp,
  }) = CodexRolloutCompactedLineDto;

  const factory CodexRolloutLineDto.unknown({
    required String? timestamp,
  }) = CodexRolloutUnknownLineDto;

  factory CodexRolloutLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutLineDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutSessionMetadataPayloadDto with _$CodexRolloutSessionMetadataPayloadDto {
  const factory CodexRolloutSessionMetadataPayloadDto({
    required String? id,
    required String? cwd,
    required String? timestamp,
    @JsonKey(name: "model_provider") required String? modelProvider,
    @JsonKey(name: "cli_version") required String? cliVersion,
  }) = _CodexRolloutSessionMetadataPayloadDto;

  factory CodexRolloutSessionMetadataPayloadDto.fromJson(Map<String, dynamic> json) =>
      _$CodexRolloutSessionMetadataPayloadDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutTurnContextPayloadDto with _$CodexRolloutTurnContextPayloadDto {
  const factory CodexRolloutTurnContextPayloadDto({
    required String? model,
  }) = _CodexRolloutTurnContextPayloadDto;

  factory CodexRolloutTurnContextPayloadDto.fromJson(Map<String, dynamic> json) =>
      _$CodexRolloutTurnContextPayloadDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutItemMetadataDto with _$CodexRolloutItemMetadataDto {
  const factory CodexRolloutItemMetadataDto({
    @JsonKey(name: "turn_id") required String? turnId,
  }) = _CodexRolloutItemMetadataDto;

  factory CodexRolloutItemMetadataDto.fromJson(Map<String, dynamic> json) =>
      _$CodexRolloutItemMetadataDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexRolloutResponseItemDto with _$CodexRolloutResponseItemDto {
  const factory CodexRolloutResponseItemDto.message({
    required String? id,
    @JsonKey(unknownEnumValue: CodexRolloutRole.unknown) required CodexRolloutRole role,
    @CodexRolloutContentListConverter() required List<CodexRolloutContentDto> content,
  }) = CodexRolloutMessageDto;

  const factory CodexRolloutResponseItemDto.reasoning({
    required String? id,
    @CodexRolloutContentListConverter() required List<CodexRolloutContentDto> summary,
  }) = CodexRolloutReasoningDto;

  @FreezedUnionValue("function_call")
  const factory CodexRolloutResponseItemDto.functionCall({
    required String? id,
    @JsonKey(name: "call_id") required String callId,
    required String name,
    required String arguments,
    @JsonKey(name: "internal_chat_message_metadata_passthrough") required CodexRolloutItemMetadataDto? metadata,
  }) = CodexRolloutFunctionCallDto;

  @FreezedUnionValue("function_call_output")
  const factory CodexRolloutResponseItemDto.functionCallOutput({
    @JsonKey(name: "call_id") required String callId,
    @CodexRolloutOutputConverter() required List<CodexRolloutContentDto> output,
  }) = CodexRolloutFunctionCallOutputDto;

  @FreezedUnionValue("custom_tool_call")
  const factory CodexRolloutResponseItemDto.customToolCall({
    required String? id,
    @JsonKey(name: "call_id") required String callId,
    required String name,
    required String input,
    @JsonKey(name: "internal_chat_message_metadata_passthrough") required CodexRolloutItemMetadataDto? metadata,
  }) = CodexRolloutCustomToolCallDto;

  @FreezedUnionValue("custom_tool_call_output")
  const factory CodexRolloutResponseItemDto.customToolCallOutput({
    @JsonKey(name: "call_id") required String callId,
    @CodexRolloutOutputConverter() required List<CodexRolloutContentDto> output,
  }) = CodexRolloutCustomToolCallOutputDto;

  @FreezedUnionValue("web_search_call")
  const factory CodexRolloutResponseItemDto.webSearchCall({
    required String? id,
    required CodexRolloutActionDto? action,
  }) = CodexRolloutWebSearchCallDto;

  @FreezedUnionValue("image_generation_call")
  const factory CodexRolloutResponseItemDto.imageGeneration({
    required String? id,
    @JsonKey(unknownEnumValue: CodexRolloutImageGenerationStatus.unknown)
    required CodexRolloutImageGenerationStatus status,
    required String result,
  }) = CodexRolloutImageGenerationDto;

  const factory CodexRolloutResponseItemDto.unknown() = CodexRolloutUnknownResponseItemDto;

  factory CodexRolloutResponseItemDto.fromJson(Map<String, dynamic> json) =>
      _$CodexRolloutResponseItemDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: true,
)
sealed class CodexRolloutContentDto with _$CodexRolloutContentDto {
  @FreezedUnionValue("input_text")
  const factory CodexRolloutContentDto.inputText({
    required String text,
  }) = CodexRolloutInputTextDto;

  @FreezedUnionValue("output_text")
  const factory CodexRolloutContentDto.outputText({
    required String text,
  }) = CodexRolloutOutputTextDto;

  @FreezedUnionValue("summary_text")
  const factory CodexRolloutContentDto.summaryText({
    required String text,
  }) = CodexRolloutSummaryTextDto;

  @FreezedUnionValue("input_image")
  const factory CodexRolloutContentDto.inputImage({
    @JsonKey(name: "image_url") required String imageUrl,
  }) = CodexRolloutInputImageDto;

  const factory CodexRolloutContentDto.unknown() = CodexRolloutUnknownContentDto;

  factory CodexRolloutContentDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutContentDtoFromJson(json);
}

/// Decodes typed rollout content without dropping an otherwise valid record
/// when one nested item has drifted.
class CodexRolloutContentListConverter implements JsonConverter<List<CodexRolloutContentDto>, Object?> {
  const CodexRolloutContentListConverter();

  @override
  List<CodexRolloutContentDto> fromJson(Object? json) {
    if (json == null) return const [];
    if (json is! List) {
      Log.w("[codex] skipping malformed rollout content list");
      return const [];
    }
    final content = <CodexRolloutContentDto>[];
    for (final item in json) {
      try {
        content.add(
          CodexRolloutContentDto.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        );
      } on Object {
        Log.w("[codex] skipping malformed rollout content item");
      }
    }
    return content;
  }

  @override
  Object toJson(List<CodexRolloutContentDto> object) {
    return [
      for (final content in object) content.toJson(),
    ];
  }
}

/// Normalizes Codex tool output across persisted rollout versions.
///
/// Legacy function-call records store output as a string, while current custom
/// tool-call records store a typed content array. The DTO exposes one typed
/// representation to the rest of the plugin.
class CodexRolloutOutputConverter extends CodexRolloutContentListConverter {
  const CodexRolloutOutputConverter();

  @override
  List<CodexRolloutContentDto> fromJson(Object? json) {
    if (json is String) {
      return [
        CodexRolloutContentDto.outputText(
          text: json,
        ),
      ];
    }
    return super.fromJson(json);
  }
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutActionDto with _$CodexRolloutActionDto {
  const factory CodexRolloutActionDto({required String? query}) = _CodexRolloutActionDto;

  factory CodexRolloutActionDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutActionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexToolArgumentsDto with _$CodexToolArgumentsDto {
  const factory CodexToolArgumentsDto({
    required Object? cmd,
    required Object? command,
    required Object? path,
    @JsonKey(name: "file_path") required Object? filePath,
    required Object? query,
  }) = _CodexToolArgumentsDto;

  factory CodexToolArgumentsDto.fromJson(Map<String, dynamic> json) => _$CodexToolArgumentsDtoFromJson(json);
}
