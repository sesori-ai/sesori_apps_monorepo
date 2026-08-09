import "package:freezed_annotation/freezed_annotation.dart";

part "claude_content_block_dto.freezed.dart";
part "claude_content_block_dto.g.dart";

@Freezed(unionKey: "type", fallbackUnion: "unknown", fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeContentBlockDto with _$ClaudeContentBlockDto {
  const factory ClaudeContentBlockDto.text({
    @JsonKey(fromJson: _stringOrNull) required String? text,
  }) = ClaudeTextContentBlockDto;

  const factory ClaudeContentBlockDto.thinking({
    @JsonKey(fromJson: _stringOrNull) required String? thinking,
    @JsonKey(fromJson: _stringOrNull) required String? signature,
  }) = ClaudeThinkingContentBlockDto;

  @FreezedUnionValue("redacted_thinking")
  const factory ClaudeContentBlockDto.unsupportedRedactedThinking() = ClaudeRedactedThinkingContentBlockDto;

  @FreezedUnionValue("tool_use")
  const factory ClaudeContentBlockDto.toolUse({
    @JsonKey(fromJson: _stringOrNull) required String? id,
    @JsonKey(fromJson: _stringOrNull) required String? name,
    required Object? input,
  }) = ClaudeToolUseContentBlockDto;

  @FreezedUnionValue("tool_result")
  const factory ClaudeContentBlockDto.toolResult({
    @JsonKey(name: "tool_use_id", fromJson: _stringOrNull) required String? toolUseId,
    required Object? content,
    @JsonKey(name: "is_error", fromJson: _boolOrNull) required bool? isError,
  }) = ClaudeToolResultContentBlockDto;

  const factory ClaudeContentBlockDto.image({
    @JsonKey(fromJson: _imageSourceOrNull) required ClaudeImageSourceDto? source,
  }) = ClaudeImageContentBlockDto;

  const factory ClaudeContentBlockDto.unknown() = ClaudeUnknownContentBlockDto;

  factory ClaudeContentBlockDto.fromJson(Map<String, dynamic> json) => _$ClaudeContentBlockDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeImageSourceDto with _$ClaudeImageSourceDto {
  const factory ClaudeImageSourceDto({
    @JsonKey(fromJson: _stringOrNull) required String? type,
    @JsonKey(name: "media_type", fromJson: _stringOrNull) required String? mediaType,
    @JsonKey(fromJson: _stringOrNull) required String? data,
  }) = _ClaudeImageSourceDto;

  factory ClaudeImageSourceDto.fromJson(Map<String, dynamic> json) => _$ClaudeImageSourceDtoFromJson(json);
}

String? _stringOrNull(Object? value) => value is String ? value : null;

bool? _boolOrNull(Object? value) => value is bool ? value : null;

ClaudeImageSourceDto? _imageSourceOrNull(Object? value) =>
    value is Map ? ClaudeImageSourceDto.fromJson(value.cast<String, dynamic>()) : null;
