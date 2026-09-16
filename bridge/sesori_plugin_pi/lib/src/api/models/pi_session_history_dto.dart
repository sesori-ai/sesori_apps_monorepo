import "package:freezed_annotation/freezed_annotation.dart";

import "../../models/pi_assistant_stop_reason.dart";
import "../../models/pi_thinking_level.dart";

part "pi_session_history_dto.freezed.dart";
part "pi_session_history_dto.g.dart";

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiSessionEntriesDto with _$PiSessionEntriesDto {
  const factory({
    required List<PiSessionEntryDto> entries,
    required String? leafId,
  }) = _PiSessionEntriesDto;

  factory fromJson(Map<String, dynamic> json) => _$PiSessionEntriesDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiSessionFileHistoryDto with _$PiSessionFileHistoryDto {
  const factory({
    required PiSessionFileHeaderDto header,
    required List<PiSessionFileEntryDto> entries,
  }) = _PiSessionFileHistoryDto;

  factory fromJson(Map<String, dynamic> json) => _$PiSessionFileHistoryDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class PiSessionFileHeaderDto with _$PiSessionFileHeaderDto {
  const factory({
    @JsonKey(fromJson: _intOrNull) required int? version,
    required String id,
  }) = _PiSessionFileHeaderDto;

  factory fromJson(Map<String, dynamic> json) => _$PiSessionFileHeaderDtoFromJson(json);
}

@Freezed(
  fromJson: true,
  toJson: false,
  toStringOverride: false,
  unionKey: "type",
  unionValueCase: FreezedUnionCase.none,
  fallbackUnion: "unknown",
)
sealed class PiSessionEntryDto with _$PiSessionEntryDto {
  @FreezedUnionValue("message")
  const factory message({
    required String id,
    required String? parentId,
    required DateTime timestamp,
    required PiAgentMessageDto message,
  }) = PiMessageEntryDto;

  @FreezedUnionValue("thinking_level_change")
  const factory thinkingLevelChange({
    required String id,
    required String? parentId,
    required DateTime timestamp,
    @JsonKey(fromJson: _thinkingLevelOrNull) required PiThinkingLevel? thinkingLevel,
  }) = PiThinkingLevelChangeEntryDto;

  @FreezedUnionValue("model_change")
  const factory modelChange({
    required String id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiModelChangeEntryDto;

  @FreezedUnionValue("compaction")
  const factory compaction({
    required String id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiCompactionEntryDto;

  @FreezedUnionValue("branch_summary")
  const factory branchSummary({
    required String id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiBranchSummaryEntryDto;

  @FreezedUnionValue("custom")
  const factory custom({
    required String id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiCustomEntryDto;

  @FreezedUnionValue("custom_message")
  const factory customMessage({
    required String id,
    required String? parentId,
    required DateTime timestamp,
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required bool display,
  }) = PiCustomMessageEntryDto;

  @FreezedUnionValue("label")
  const factory label({
    required String id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiLabelEntryDto;

  @FreezedUnionValue("session_info")
  const factory sessionInfo({
    required String id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiSessionInfoEntryDto;

  const factory unknown({
    required String id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiUnknownEntryDto;

  factory fromJson(Map<String, dynamic> json) => _$PiSessionEntryDtoFromJson(json);
}

@Freezed(
  fromJson: true,
  toJson: false,
  toStringOverride: false,
  unionKey: "type",
  unionValueCase: FreezedUnionCase.none,
  fallbackUnion: "unknown",
)
sealed class PiSessionFileEntryDto with _$PiSessionFileEntryDto {
  @FreezedUnionValue("message")
  const factory message({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
    required PiSessionFileAgentMessageDto message,
  }) = PiSessionFileMessageEntryDto;

  @FreezedUnionValue("thinking_level_change")
  const factory thinkingLevelChange({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
    @JsonKey(fromJson: _thinkingLevelOrNull) required PiThinkingLevel? thinkingLevel,
  }) = PiSessionFileThinkingLevelChangeEntryDto;

  @FreezedUnionValue("model_change")
  const factory modelChange({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiSessionFileModelChangeEntryDto;

  @FreezedUnionValue("compaction")
  const factory compaction({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiSessionFileCompactionEntryDto;

  @FreezedUnionValue("branch_summary")
  const factory branchSummary({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiSessionFileBranchSummaryEntryDto;

  @FreezedUnionValue("custom")
  const factory custom({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiSessionFileCustomEntryDto;

  @FreezedUnionValue("custom_message")
  const factory customMessage({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required bool display,
  }) = PiSessionFileCustomMessageEntryDto;

  @FreezedUnionValue("label")
  const factory label({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiSessionFileLabelEntryDto;

  @FreezedUnionValue("session_info")
  const factory sessionInfo({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiSessionFileSessionInfoEntryDto;

  const factory unknown({
    required String? id,
    required String? parentId,
    required DateTime timestamp,
  }) = PiSessionFileUnknownEntryDto;

  factory fromJson(Map<String, dynamic> json) => _$PiSessionFileEntryDtoFromJson(json);
}

@Freezed(
  fromJson: true,
  toJson: false,
  toStringOverride: false,
  unionKey: "role",
  unionValueCase: FreezedUnionCase.none,
  fallbackUnion: "unknown",
)
sealed class PiSessionFileAgentMessageDto with _$PiSessionFileAgentMessageDto {
  @FreezedUnionValue("user")
  const factory user({
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileUserMessageDto;

  @FreezedUnionValue("assistant")
  const factory assistant({
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required String? provider,
    required String? model,
    @JsonKey(fromJson: _stopReasonOrNull) required PiAssistantStopReason? stopReason,
    required String? errorMessage,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileAssistantMessageDto;

  @FreezedUnionValue("toolResult")
  const factory toolResult({
    required String toolCallId,
    required String toolName,
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required bool isError,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileToolResultMessageDto;

  @FreezedUnionValue("bashExecution")
  const factory bashExecution({
    required String command,
    required String output,
    @JsonKey(fromJson: _intOrNull) required int? exitCode,
    required bool cancelled,
    required bool truncated,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileBashExecutionMessageDto;

  @FreezedUnionValue("custom")
  const factory custom({
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required bool display,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileCustomMessageDto;

  @FreezedUnionValue("hookMessage")
  const factory hookMessage({
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required bool display,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileHookMessageDto;

  @FreezedUnionValue("branchSummary")
  const factory branchSummary({
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileBranchSummaryMessageDto;

  @FreezedUnionValue("compactionSummary")
  const factory compactionSummary({
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileCompactionSummaryMessageDto;

  const factory unknown({
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiSessionFileUnknownMessageDto;

  factory fromJson(Map<String, dynamic> json) => _$PiSessionFileAgentMessageDtoFromJson(json);
}

@Freezed(
  fromJson: true,
  toJson: false,
  toStringOverride: false,
  unionKey: "role",
  unionValueCase: FreezedUnionCase.none,
  fallbackUnion: "unknown",
)
sealed class PiAgentMessageDto with _$PiAgentMessageDto {
  @FreezedUnionValue("user")
  const factory user({
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiUserMessageDto;

  @FreezedUnionValue("assistant")
  const factory assistant({
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required String? provider,
    required String? model,
    @JsonKey(fromJson: _stopReasonOrNull) required PiAssistantStopReason? stopReason,
    required String? errorMessage,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiAssistantMessageDto;

  @FreezedUnionValue("toolResult")
  const factory toolResult({
    required String toolCallId,
    required String toolName,
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required bool isError,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiToolResultMessageDto;

  @FreezedUnionValue("bashExecution")
  const factory bashExecution({
    required String command,
    required String output,
    @JsonKey(fromJson: _intOrNull) required int? exitCode,
    required bool cancelled,
    required bool truncated,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiBashExecutionMessageDto;

  @FreezedUnionValue("custom")
  const factory custom({
    @JsonKey(fromJson: _contentFromJson) required List<PiContentDto> content,
    required bool display,
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiCustomMessageDto;

  @FreezedUnionValue("branchSummary")
  const factory branchSummary({
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiBranchSummaryMessageDto;

  @FreezedUnionValue("compactionSummary")
  const factory compactionSummary({
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiCompactionSummaryMessageDto;

  const factory unknown({
    @JsonKey(fromJson: _intOrNull) required int? timestamp,
  }) = PiUnknownMessageDto;

  factory fromJson(Map<String, dynamic> json) => _$PiAgentMessageDtoFromJson(json);
}

@Freezed(
  fromJson: true,
  toJson: false,
  toStringOverride: false,
  unionKey: "type",
  unionValueCase: FreezedUnionCase.none,
  fallbackUnion: "unknown",
)
sealed class PiContentDto with _$PiContentDto {
  @FreezedUnionValue("text")
  const factory text({required String text}) = PiTextContentDto;

  @FreezedUnionValue("image")
  const factory image({
    required String data,
    required String mimeType,
  }) = PiImageContentDto;

  @FreezedUnionValue("thinking")
  const factory thinking({
    required String thinking,
    required bool? redacted,
  }) = PiThinkingContentDto;

  @FreezedUnionValue("toolCall")
  const factory toolCall({
    required String id,
    required String name,
    required Object? arguments,
  }) = PiToolCallContentDto;

  const factory unknown() = PiUnknownContentDto;

  factory fromJson(Map<String, dynamic> json) => _$PiContentDtoFromJson(json);
}

List<PiContentDto> _contentFromJson(Object? value) {
  if (value == null) return const [];
  if (value is String) return [PiContentDto.text(text: value)];
  if (value is! List) throw const FormatException("Expected message content");
  return [
    for (final block in value)
      PiContentDto.fromJson(
        block is Map<String, dynamic> ? block : throw const FormatException("Expected message content object"),
      ),
  ];
}

int? _intOrNull(Object? value) => value is num && value.isFinite ? value.toInt() : null;

PiAssistantStopReason? _stopReasonOrNull(Object? value) =>
    PiAssistantStopReason.tryParse(value: value is String ? value : null);

PiThinkingLevel? _thinkingLevelOrNull(Object? value) => PiThinkingLevel.tryParse(value: value is String ? value : null);
