import "package:freezed_annotation/freezed_annotation.dart";

part "codex_sub_agent_item_dto.freezed.dart";
part "codex_sub_agent_item_dto.g.dart";

enum CodexSubAgentActivityKind() {
  started,
  interacted,
  interrupted,
  completed,
  unknown,
}

String? _textFromJson(Object? value) => value is String ? value : null;

@Freezed(fromJson: true, toJson: false)
sealed class CodexSubAgentItemParamsDto with _$CodexSubAgentItemParamsDto {
  const factory({
    required String? threadId,
    required String? turnId,
    required CodexSubAgentItemDto item,
  }) = _CodexSubAgentItemParamsDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemParamsDtoFromJson(json);
}

/// The multi-agent items the pinned codex-cli app-server emits on the parent
/// thread, discriminated by `type`: `subAgentActivity` with `multi_agent_v2`
/// on, `collabAgentToolCall` for the default `multi_agent_v1` tools (and for
/// v2's `wait_agent`, which has no consumer).
@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexSubAgentItemDto with _$CodexSubAgentItemDto {
  @FreezedUnionValue("subAgentActivity")
  const factory subAgentActivity({
    required String? id,
    @JsonKey(
      unknownEnumValue: CodexSubAgentActivityKind.unknown,
      defaultValue: CodexSubAgentActivityKind.unknown,
    )
    required CodexSubAgentActivityKind kind,
    @JsonKey(fromJson: _textFromJson) required String? agentThreadId,
    @JsonKey(fromJson: _textFromJson) required String? agentPath,

    /// Resolved at sub-agent creation; only `started` activities carry them,
    /// and not before codex-cli 0.167.
    @JsonKey(fromJson: _textFromJson) required String? model,
    @JsonKey(fromJson: _textFromJson) required String? reasoningEffort,
  }) = CodexSubAgentActivityItemDto;

  /// A `multi_agent_v1` call. A completed `spawnAgent` names the spawned
  /// child in [receiverThreadIds]; its started frame names none yet.
  @FreezedUnionValue("collabAgentToolCall")
  const factory collabAgentToolCall({
    required String? id,
    @JsonKey(fromJson: _textFromJson) required String? tool,
    @Default(<String>[]) List<String> receiverThreadIds,
    @JsonKey(fromJson: _textFromJson) required String? model,
    @JsonKey(fromJson: _textFromJson) required String? reasoningEffort,
  }) = CodexCollabAgentToolCallItemDto;

  const factory unknown() = CodexUnknownSubAgentItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemDtoFromJson(json);
}
