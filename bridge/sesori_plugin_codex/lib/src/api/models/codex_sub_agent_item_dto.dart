import "package:freezed_annotation/freezed_annotation.dart";

part "codex_sub_agent_item_dto.freezed.dart";
part "codex_sub_agent_item_dto.g.dart";

enum CodexCollabTool() {
  spawnAgent,
  sendInput,
  resumeAgent,
  wait,
  closeAgent,
  unknown,
}

enum CodexCollabItemStatus() {
  inProgress,
  completed,
  failed,
  unknown,
}

enum CodexCollabAgentStatus() {
  pendingInit,
  running,
  completed,
  failed,
  interrupted,
  errored,
  shutdown,
  notFound,
  unknown,
}

enum CodexSubAgentActivityKind() {
  started,
  interacted,
  interrupted,
  completed,
  unknown,
}

String? _textFromJson(Object? value) => value is String ? value : null;

List<String> _threadIdListFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final entry in value)
      if (entry is String) entry,
  ];
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSubAgentItemParamsDto with _$CodexSubAgentItemParamsDto {
  const factory({
    required String? threadId,
    required String? turnId,
    required CodexSubAgentItemDto item,
  }) = _CodexSubAgentItemParamsDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemParamsDtoFromJson(json);
}

/// One value of `agentsStates`: the receiver thread's status plus an optional
/// human-readable message.
@Freezed(fromJson: true, toJson: false)
sealed class CodexCollabAgentStateDto with _$CodexCollabAgentStateDto {
  const factory({
    @JsonKey(
      unknownEnumValue: CodexCollabAgentStatus.unknown,
      defaultValue: CodexCollabAgentStatus.unknown,
    )
    required CodexCollabAgentStatus status,
    @JsonKey(fromJson: _textFromJson) required String? message,
  }) = _CodexCollabAgentStateDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexCollabAgentStateDtoFromJson(json);
}

/// Item shapes the pinned codex-cli 0.148.0 app-server emits for multi-agent
/// activity on the parent thread, discriminated by `type`.
@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: false,
)
sealed class CodexSubAgentItemDto with _$CodexSubAgentItemDto {
  @FreezedUnionValue("collabAgentToolCall")
  const factory collabAgentToolCall({
    required String? id,
    @JsonKey(unknownEnumValue: CodexCollabTool.unknown, defaultValue: CodexCollabTool.unknown)
    required CodexCollabTool tool,
    @JsonKey(
      unknownEnumValue: CodexCollabItemStatus.unknown,
      defaultValue: CodexCollabItemStatus.unknown,
    )
    required CodexCollabItemStatus status,
    @JsonKey(fromJson: _textFromJson) required String? senderThreadId,
    @JsonKey(fromJson: _threadIdListFromJson) required List<String> receiverThreadIds,
    @JsonKey(fromJson: _textFromJson) required String? prompt,
    @JsonKey(defaultValue: <String, CodexCollabAgentStateDto>{})
    required Map<String, CodexCollabAgentStateDto> agentsStates,
  }) = CodexCollabAgentToolCallItemDto;

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
  }) = CodexSubAgentActivityItemDto;

  const factory unknown() = CodexUnknownSubAgentItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemDtoFromJson(json);
}
