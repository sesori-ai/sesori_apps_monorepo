import "package:freezed_annotation/freezed_annotation.dart";

part "codex_rollout_dto.freezed.dart";
part "codex_rollout_dto.g.dart";

enum CodexRolloutLineType {
  @JsonValue("session_meta")
  sessionMeta,
  @JsonValue("turn_context")
  turnContext,
  @JsonValue("response_item")
  responseItem,
  unknown,
}

enum CodexRolloutPayloadType {
  message,
  reasoning,
  @JsonValue("function_call")
  functionCall,
  @JsonValue("function_call_output")
  functionCallOutput,
  @JsonValue("custom_tool_call")
  customToolCall,
  @JsonValue("custom_tool_call_output")
  customToolCallOutput,
  @JsonValue("web_search_call")
  webSearchCall,
  unknown,
}

enum CodexRolloutRole {
  user,
  assistant,
  unknown,
}

enum CodexRolloutContentType {
  @JsonValue("input_text")
  inputText,
  @JsonValue("output_text")
  outputText,
  @JsonValue("summary_text")
  summaryText,
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

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutLineDto with _$CodexRolloutLineDto {
  const factory CodexRolloutLineDto({
    required String? timestamp,
    @JsonKey(unknownEnumValue: CodexRolloutLineType.unknown) required CodexRolloutLineType? type,
    required CodexRolloutPayloadDto? payload,
  }) = _CodexRolloutLineDto;

  factory CodexRolloutLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutLineDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutPayloadDto with _$CodexRolloutPayloadDto {
  const factory CodexRolloutPayloadDto({
    required String? id,
    required String? cwd,
    required String? timestamp,
    @JsonKey(name: "model_provider") required String? modelProvider,
    @JsonKey(name: "cli_version") required String? cliVersion,
    required String? model,
    @JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) required CodexRolloutPayloadType? type,
    @JsonKey(unknownEnumValue: CodexRolloutRole.unknown) required CodexRolloutRole? role,
    // Payload variants reuse these fields with different shapes. In
    // particular, codex 0.144.x custom tool outputs are typed content arrays,
    // while legacy function outputs are strings. Preserve the wire value here
    // and narrow it in the repository after inspecting the payload type.
    required Object? content,
    required Object? summary,
    @JsonKey(name: "call_id") required String? callId,
    required String? name,
    required String? arguments,
    required String? input,
    required Object? output,
    required CodexRolloutActionDto? action,
  }) = _CodexRolloutPayloadDto;

  factory CodexRolloutPayloadDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutPayloadDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexRolloutContentDto with _$CodexRolloutContentDto {
  const factory CodexRolloutContentDto({
    @JsonKey(unknownEnumValue: CodexRolloutContentType.unknown) required CodexRolloutContentType? type,
    required String? text,
  }) = _CodexRolloutContentDto;

  factory CodexRolloutContentDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutContentDtoFromJson(json);
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
