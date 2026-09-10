import "package:freezed_annotation/freezed_annotation.dart";

import "grok_session_notification_dto.dart";

part "grok_session_store_dto.freezed.dart";
part "grok_session_store_dto.g.dart";

/// `session_kind` in a persisted Grok `summary.json`. A root session omits the
/// field; a sub-agent's summary carries `subagent`. Anything else is unknown.
enum GrokSessionKind() {
  @JsonValue("build")
  build,
  @JsonValue("subagent")
  subagent,
  unknown,
}

/// `<session>/summary.json` under `~/.grok/sessions/<encoded cwd>/`, as
/// persisted by Grok Build 1.0.5. Only the fields the catalog reads are
/// modeled; the summary carries no parent id, so parentage comes from the
/// root's persisted spawn records instead.
@Freezed(fromJson: true, toJson: false)
sealed class GrokSessionSummaryDto with _$GrokSessionSummaryDto {
  const factory({
    required GrokSessionSummaryInfoDto? info,
    @JsonKey(name: "session_kind", unknownEnumValue: GrokSessionKind.unknown) required GrokSessionKind? sessionKind,
    @JsonKey(name: "agent_name") required String? agentName,
    @JsonKey(name: "generated_title") required String? generatedTitle,
    @JsonKey(name: "created_at") required String? createdAt,
    @JsonKey(name: "updated_at") required String? updatedAt,
  }) = _GrokSessionSummaryDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokSessionSummaryDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GrokSessionSummaryInfoDto with _$GrokSessionSummaryInfoDto {
  const factory({
    required String? id,
    required String? cwd,
  }) = _GrokSessionSummaryInfoDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokSessionSummaryInfoDtoFromJson(json);
}

/// One line of `<session>/updates.jsonl`. Grok extension lifecycle and
/// standard ACP updates stay typed and ordered; every other persisted method
/// remains an explicit boundary so repository logic cannot accidentally merge
/// user-message runs across unknown records.
@Freezed(
  unionKey: "method",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class GrokPersistedUpdateDto with _$GrokPersistedUpdateDto {
  @FreezedUnionValue("_x.ai/session/update")
  const factory grokSessionUpdate({
    required GrokSessionNotificationDto params,
  }) = GrokPersistedGrokSessionUpdateDto;

  @FreezedUnionValue("session/update")
  const factory acpSessionUpdate({
    required GrokPersistedAcpNotificationDto params,
  }) = GrokPersistedAcpSessionUpdateDto;

  const factory unknown() = GrokPersistedUpdateUnknownDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokPersistedUpdateDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GrokPersistedAcpNotificationDto with _$GrokPersistedAcpNotificationDto {
  const factory({
    required String sessionId,
    required GrokPersistedAcpUpdateDto update,
  }) = _GrokPersistedAcpNotificationDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokPersistedAcpNotificationDtoFromJson(json);
}

/// Standard ACP update kinds needed by history preparation. Unknown updates
/// remain typed boundaries; known content variants can evolve independently.
@Freezed(
  unionKey: "sessionUpdate",
  unionValueCase: FreezedUnionCase.snake,
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class GrokPersistedAcpUpdateDto with _$GrokPersistedAcpUpdateDto {
  const factory userMessageChunk({
    required GrokPersistedContentDto content,
  }) = GrokPersistedUserMessageChunkDto;

  const factory unknown() = GrokPersistedAcpUpdateUnknownDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokPersistedAcpUpdateDtoFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class GrokPersistedContentDto with _$GrokPersistedContentDto {
  const factory text({required String text}) = GrokPersistedTextContentDto;

  const factory unknown() = GrokPersistedContentUnknownDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokPersistedContentDtoFromJson(json);
}
