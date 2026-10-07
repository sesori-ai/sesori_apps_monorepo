import "package:freezed_annotation/freezed_annotation.dart";

part "cursor_subagent_update_dto.freezed.dart";
part "cursor_subagent_update_dto.g.dart";

/// Cursor's terminal sub-agent states. A spawn implies running; Cursor sends
/// no running state.
enum CursorSubagentState() {
  @JsonValue("completed")
  completed,
  @JsonValue("failed")
  failed,
  @JsonValue("cancelled")
  cancelled,

  /// The root cancel cascade timed out, or the outcome is otherwise unknown.
  @JsonValue("disconnected")
  disconnected,
  @JsonValue("unknown")
  unknown,
}

/// Cursor's sub-agent lifecycle `session/update` kinds, sent while the
/// connection advertises `_meta.subagents`. The envelope's `sessionId` is the
/// parent that launched the child: the root, or a running child for nested
/// sub-agents. Every other kind is [CursorSubagentUpdateUnknownDto].
@Freezed(
  unionKey: "sessionUpdate",
  unionValueCase: FreezedUnionCase.snake,
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CursorSubagentUpdateDto with _$CursorSubagentUpdateDto {
  /// A child session started. A resumed child run gets a new
  /// `<agentId>.<n>` [subagentSessionId] and its own spawn.
  const factory subagentSpawned({
    required String subagentSessionId,

    /// The sub-agent type, or Cursor's generic `subagent`.
    required String? name,

    /// The task title; Cursor sends an empty string when it has none.
    required String? task,
    @JsonKey(name: "_meta") required CursorSubagentMetaDto? meta,
  }) = CursorSubagentSpawnedDto;

  const factory subagentStateUpdate({
    required String subagentSessionId,
    @JsonKey(unknownEnumValue: CursorSubagentState.unknown) required CursorSubagentState state,
  }) = CursorSubagentStateUpdateDto;

  const factory unknown() = CursorSubagentUpdateUnknownDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorSubagentUpdateDtoFromJson(json);
}

/// `_meta` of a sub-agent update.
@Freezed(fromJson: true, toJson: false)
sealed class CursorSubagentMetaDto with _$CursorSubagentMetaDto {
  const factory({required CursorSubagentCursorMetaDto? cursor}) = _CursorSubagentMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorSubagentMetaDtoFromJson(json);
}

/// Cursor's link from a child to the parent's Task tool call, plus the
/// child's model when Cursor knows it.
@Freezed(fromJson: true, toJson: false)
sealed class CursorSubagentCursorMetaDto with _$CursorSubagentCursorMetaDto {
  const factory({
    required String? toolCallId,
    required String? model,
  }) = _CursorSubagentCursorMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorSubagentCursorMetaDtoFromJson(json);
}
