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

/// The multi-agent item the pinned codex-cli app-server emits on the parent
/// thread, discriminated by `type`. Other multi-agent items, such as
/// `collabAgentToolCall`, have no consumer and fall to [unknown].
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

  const factory unknown() = CodexUnknownSubAgentItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemDtoFromJson(json);
}
