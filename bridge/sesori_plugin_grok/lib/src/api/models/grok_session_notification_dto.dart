import "package:freezed_annotation/freezed_annotation.dart";

import "../../models/grok_subagent_status.dart";

part "grok_session_notification_dto.freezed.dart";
part "grok_session_notification_dto.g.dart";

/// Params of Grok Build's `_x.ai/session_notification`: the parent session and
/// an internally tagged update. Only the sub-agent lifecycle variants are
/// modeled; every other `sessionUpdate` parses as [GrokSubagentUpdateUnknown].
@Freezed(fromJson: true, toJson: false)
sealed class GrokSessionNotificationDto with _$GrokSessionNotificationDto {
  const factory({
    required String sessionId,
    required GrokSubagentUpdate update,
  }) = _GrokSessionNotificationDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokSessionNotificationDtoFromJson(json);
}

/// The sub-agent lifecycle updates Grok Build wraps in a session notification.
/// The envelope's `sessionId` is the parent; `subagentId` equals the child
/// session id on 1.0.5 and is kept only because the cancel request names it.
@Freezed(
  unionKey: "sessionUpdate",
  unionValueCase: FreezedUnionCase.snake,
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class GrokSubagentUpdate with _$GrokSubagentUpdate {
  const factory subagentSpawned({
    @JsonKey(name: "subagent_id") required String subagentId,
    @JsonKey(name: "child_session_id") required String childSessionId,
    @JsonKey(name: "subagent_type") required String? subagentType,
    required String? description,

    /// The model the child runs on, which may differ from the root's.
    required String? model,
  }) = GrokSubagentSpawned;

  const factory subagentProgress({
    @JsonKey(name: "subagent_id") required String subagentId,
  }) = GrokSubagentProgress;

  const factory subagentFinished({
    @JsonKey(name: "subagent_id") required String subagentId,
    @JsonKey(name: "child_session_id") required String childSessionId,
    @JsonKey(unknownEnumValue: GrokSubagentStatus.unknown) required GrokSubagentStatus status,
    required String? output,
    required String? error,
    @JsonKey(name: "will_wake") required bool? willWake,
  }) = GrokSubagentFinished;

  const factory turnCompleted({
    @JsonKey(name: "prompt_id") required String? promptId,
  }) = GrokTurnCompleted;

  const factory unknown() = GrokSubagentUpdateUnknown;

  factory fromJson(Map<String, dynamic> json) => _$GrokSubagentUpdateFromJson(json);
}

/// Grok's `_meta` on a standard `tool_call`: the tool identity behind the
/// generic title.
@Freezed(fromJson: true, toJson: false)
sealed class GrokToolCallMetaDto with _$GrokToolCallMetaDto {
  const factory({
    @JsonKey(name: "x.ai/tool") required GrokToolIdentityDto? tool,
  }) = _GrokToolCallMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokToolCallMetaDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GrokToolIdentityDto with _$GrokToolIdentityDto {
  const factory({
    required String? name,
    required String? kind,
  }) = _GrokToolIdentityDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokToolIdentityDtoFromJson(json);
}
