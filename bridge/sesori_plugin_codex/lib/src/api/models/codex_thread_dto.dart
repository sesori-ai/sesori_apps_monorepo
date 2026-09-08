import "package:freezed_annotation/freezed_annotation.dart";

part "codex_thread_dto.freezed.dart";
part "codex_thread_dto.g.dart";

/// Origin of a Codex app-server thread. `null` on the wire for root threads
/// and, on codex-cli 0.148.0, also for live sub-agent threads; `parentThreadId`
/// is the authoritative parentage signal there.
enum CodexThreadSource() {
  subAgent,
  subAgentReview,
  subAgentCompact,
  subAgentThreadSpawn,
  subAgentOther,
  unknown,
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexThreadEnvelopeDto with _$CodexThreadEnvelopeDto {
  const factory({
    required CodexThreadDto? thread,
    required String? model,
    required String? modelProvider,
    required String? cwd,
  }) = _CodexThreadEnvelopeDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexThreadEnvelopeDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexThreadTurnDto with _$CodexThreadTurnDto {
  const factory({
    @JsonKey(defaultValue: <CodexThreadItemDto>[]) required List<CodexThreadItemDto> items,
  }) = _CodexThreadTurnDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexThreadTurnDtoFromJson(json);
}

@Freezed(unionKey: "type", fallbackUnion: "unknown", fromJson: true, toJson: false)
sealed class CodexThreadItemDto with _$CodexThreadItemDto {
  @FreezedUnionValue("userMessage")
  const factory userMessage({
    @JsonKey(defaultValue: <CodexThreadContentDto>[]) required List<CodexThreadContentDto> content,
  }) = CodexThreadUserMessageItemDto;

  const factory unknown() = CodexThreadUnknownItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexThreadItemDtoFromJson(json);
}

@Freezed(unionKey: "type", fallbackUnion: "unknown", fromJson: true, toJson: false)
sealed class CodexThreadContentDto with _$CodexThreadContentDto {
  @FreezedUnionValue("text")
  const factory text({required String text}) = CodexThreadTextContentDto;

  @FreezedUnionValue("input_text")
  const factory inputText({required String text}) = CodexThreadInputTextContentDto;

  const factory unknown() = CodexThreadUnknownContentDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexThreadContentDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexThreadDto with _$CodexThreadDto {
  const factory({
    required String? id,
    required String? name,
    required String? cwd,
    required num? createdAt,
    required num? updatedAt,
    required String? modelProvider,
    required String? parentThreadId,
    required String? agentNickname,
    required String? agentRole,
    @JsonKey(unknownEnumValue: CodexThreadSource.unknown) required CodexThreadSource? threadSource,
    @JsonKey(defaultValue: <CodexThreadTurnDto>[]) required List<CodexThreadTurnDto> turns,
  }) = _CodexThreadDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexThreadDtoFromJson(json);
}
