import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

part "codex_rollout_dto.freezed.dart";
part "codex_rollout_dto.g.dart";

enum CodexRolloutRole() {
  user,
  assistant,
  unknown,
}

enum CodexRolloutImageGenerationStatus() {
  @JsonValue("in_progress")
  inProgress,
  completed,
  failed,
  unknown,
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSessionIndexEntryDto with _$CodexSessionIndexEntryDto {
  const factory({
    required String? id,
    @JsonKey(name: "thread_name") required String? threadName,
    @JsonKey(name: "updated_at") required String? updatedAt,
  }) = _CodexSessionIndexEntryDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSessionIndexEntryDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexRolloutLineDto with _$CodexRolloutLineDto {
  @FreezedUnionValue("session_meta")
  const factory sessionMetadata({
    required String? timestamp,
    required CodexRolloutSessionMetadataPayloadDto payload,
  }) = CodexRolloutSessionMetadataLineDto;

  @FreezedUnionValue("turn_context")
  const factory turnContext({
    required String? timestamp,
    required CodexRolloutTurnContextPayloadDto payload,
  }) = CodexRolloutTurnContextLineDto;

  @FreezedUnionValue("response_item")
  const factory responseItem({
    required String? timestamp,
    required CodexRolloutResponseItemDto payload,
  }) = CodexRolloutResponseItemLineDto;

  @FreezedUnionValue("event_msg")
  const factory eventMessage({
    required String? timestamp,
    required CodexRolloutEventDto payload,
  }) = CodexRolloutEventMessageLineDto;

  @FreezedUnionValue("compacted")
  const factory compacted({
    required String? timestamp,
  }) = CodexRolloutCompactedLineDto;

  const factory unknown({
    required String? timestamp,
  }) = CodexRolloutUnknownLineDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutLineDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexRolloutEventDto with _$CodexRolloutEventDto {
  @FreezedUnionValue("user_message")
  const factory userMessage({
    required String message,
  }) = CodexRolloutUserMessageEventDto;

  @FreezedUnionValue("image_generation_end")
  const factory imageGenerationEnd({
    @JsonKey(name: "call_id") required String callId,
    @JsonKey(unknownEnumValue: CodexRolloutImageGenerationStatus.unknown)
    required CodexRolloutImageGenerationStatus status,
    @JsonKey(name: "revised_prompt") required String? revisedPrompt,
    required String result,
    @JsonKey(name: "saved_path") required String? savedPath,
  }) = CodexRolloutImageGenerationEndEventDto;

  @FreezedUnionValue("task_started")
  const factory taskStarted({
    @JsonKey(name: "turn_id") required String turnId,
  }) = CodexRolloutTaskStartedEventDto;

  @FreezedUnionValue("task_complete")
  const factory taskComplete({
    @JsonKey(name: "turn_id") required String turnId,
    required CodexRolloutErrorDto? error,
  }) = CodexRolloutTaskCompleteEventDto;

  @FreezedUnionValue("turn_aborted")
  const factory turnAborted({
    @JsonKey(name: "turn_id") required String? turnId,
  }) = CodexRolloutTurnAbortedEventDto;

  const factory unknown() = CodexRolloutUnknownEventDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutEventDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutErrorDto with _$CodexRolloutErrorDto {
  const factory({
    required String message,
  }) = _CodexRolloutErrorDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutErrorDtoFromJson(json);
}

/// Persisted `session_meta.thread_source`; absent for root rollouts.
enum CodexRolloutThreadSource() {
  subagent,
  unknown,
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutSessionMetadataPayloadDto with _$CodexRolloutSessionMetadataPayloadDto {
  const factory({
    required String? id,
    required String? cwd,
    required String? timestamp,
    @JsonKey(name: "model_provider") required String? modelProvider,
    @JsonKey(name: "cli_version") required String? cliVersion,
    @JsonKey(name: "parent_thread_id") required String? parentThreadId,
    @JsonKey(name: "thread_source", unknownEnumValue: CodexRolloutThreadSource.unknown)
    required CodexRolloutThreadSource? threadSource,
    @JsonKey(name: "agent_nickname") required String? agentNickname,
    @JsonKey(name: "agent_path") required String? agentPath,
  }) = _CodexRolloutSessionMetadataPayloadDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutSessionMetadataPayloadDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutTurnContextPayloadDto with _$CodexRolloutTurnContextPayloadDto {
  const factory({
    required String? model,
    @JsonKey(name: "reasoning_effort", fromJson: _stringOrNull) required String? effort,
  }) = _CodexRolloutTurnContextPayloadDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutTurnContextPayloadDtoFromJson(json);
}

String? _stringOrNull(Object? value) => value is String ? value : null;

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutItemMetadataDto with _$CodexRolloutItemMetadataDto {
  const factory({
    @JsonKey(name: "turn_id") required String? turnId,
  }) = _CodexRolloutItemMetadataDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutItemMetadataDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexRolloutResponseItemDto with _$CodexRolloutResponseItemDto {
  const factory message({
    required String? id,
    @JsonKey(unknownEnumValue: CodexRolloutRole.unknown) required CodexRolloutRole role,
    @CodexRolloutContentListConverter() required List<CodexRolloutContentDto> content,
  }) = CodexRolloutMessageDto;

  const factory reasoning({
    required String? id,
    @CodexRolloutContentListConverter() required List<CodexRolloutContentDto> summary,
  }) = CodexRolloutReasoningDto;

  @FreezedUnionValue("function_call")
  const factory functionCall({
    required String? id,
    @JsonKey(name: "call_id") required String callId,
    required String name,
    required String arguments,
    @JsonKey(name: "internal_chat_message_metadata_passthrough") required CodexRolloutItemMetadataDto? metadata,
  }) = CodexRolloutFunctionCallDto;

  @FreezedUnionValue("function_call_output")
  const factory functionCallOutput({
    @JsonKey(name: "call_id") required String callId,
    @CodexRolloutOutputConverter() required List<CodexRolloutContentDto> output,
  }) = CodexRolloutFunctionCallOutputDto;

  @FreezedUnionValue("custom_tool_call")
  const factory customToolCall({
    required String? id,
    @JsonKey(name: "call_id") required String callId,
    required String name,
    required String input,
    @JsonKey(name: "internal_chat_message_metadata_passthrough") required CodexRolloutItemMetadataDto? metadata,
  }) = CodexRolloutCustomToolCallDto;

  @FreezedUnionValue("custom_tool_call_output")
  const factory customToolCallOutput({
    @JsonKey(name: "call_id") required String callId,
    @CodexRolloutOutputConverter() required List<CodexRolloutContentDto> output,
  }) = CodexRolloutCustomToolCallOutputDto;

  @FreezedUnionValue("web_search_call")
  const factory webSearchCall({
    required String? id,
    required CodexRolloutActionDto? action,
  }) = CodexRolloutWebSearchCallDto;

  @FreezedUnionValue("image_generation_call")
  const factory imageGeneration({
    required String? id,
    @JsonKey(unknownEnumValue: CodexRolloutImageGenerationStatus.unknown)
    required CodexRolloutImageGenerationStatus status,
    required String result,
  }) = CodexRolloutImageGenerationDto;

  const factory unknown() = CodexRolloutUnknownResponseItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutResponseItemDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: true,
)
sealed class CodexRolloutContentDto with _$CodexRolloutContentDto {
  @FreezedUnionValue("input_text")
  const factory inputText({
    required String text,
  }) = CodexRolloutInputTextDto;

  @FreezedUnionValue("output_text")
  const factory outputText({
    required String text,
  }) = CodexRolloutOutputTextDto;

  @FreezedUnionValue("summary_text")
  const factory summaryText({
    required String text,
  }) = CodexRolloutSummaryTextDto;

  @FreezedUnionValue("input_image")
  const factory inputImage({
    @JsonKey(name: "image_url") required String imageUrl,
  }) = CodexRolloutInputImageDto;

  const factory unknown() = CodexRolloutUnknownContentDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutContentDtoFromJson(json);
}

/// Decodes typed rollout content without dropping an otherwise valid record
/// when one nested item has drifted.
class const CodexRolloutContentListConverter() implements JsonConverter<List<CodexRolloutContentDto>, Object?> {
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
class const CodexRolloutOutputConverter() extends CodexRolloutContentListConverter {
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
  const factory({required String? query}) = _CodexRolloutActionDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexRolloutActionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexToolArgumentsDto with _$CodexToolArgumentsDto {
  const factory({
    required Object? cmd,
    required Object? command,
    required Object? path,
    @JsonKey(name: "file_path") required Object? filePath,
    required Object? query,
    @JsonKey(name: "cell_id") required Object? cellId,
    @JsonKey(name: "task_name", fromJson: _stringOrNull) required String? taskName,
    @JsonKey(fromJson: _stringOrNull) required String? message,
    @JsonKey(name: "agent_type", fromJson: _stringOrNull) required String? agentType,
  }) = _CodexToolArgumentsDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexToolArgumentsDtoFromJson(json);
}
