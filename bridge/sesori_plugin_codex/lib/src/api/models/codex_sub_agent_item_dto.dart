import "package:freezed_annotation/freezed_annotation.dart";

part "codex_sub_agent_item_dto.freezed.dart";
part "codex_sub_agent_item_dto.g.dart";

/// Item types the app-server emits for multi-agent activity on the parent
/// thread. codex-cli 0.148.0 names the tool-call item `collabAgentToolCall`;
/// upstream `main` renamed it to `collabToolCall`, so both decode identically.
enum CodexSubAgentItemType() {
  @JsonValue("collabAgentToolCall")
  collabAgentToolCall,
  @JsonValue("collabToolCall")
  collabToolCall,
  @JsonValue("subAgentActivity")
  subAgentActivity,
  unknown,
}

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

CodexCollabTool _collabToolFromJson(Object? value) {
  return switch (value) {
    "spawnAgent" => CodexCollabTool.spawnAgent,
    "sendInput" => CodexCollabTool.sendInput,
    "resumeAgent" => CodexCollabTool.resumeAgent,
    "wait" => CodexCollabTool.wait,
    "closeAgent" => CodexCollabTool.closeAgent,
    _ => CodexCollabTool.unknown,
  };
}

CodexCollabItemStatus _collabItemStatusFromJson(Object? value) {
  return switch (value) {
    "inProgress" => CodexCollabItemStatus.inProgress,
    "completed" => CodexCollabItemStatus.completed,
    "failed" => CodexCollabItemStatus.failed,
    _ => CodexCollabItemStatus.unknown,
  };
}

CodexSubAgentActivityKind _activityKindFromJson(Object? value) {
  return switch (value) {
    "started" => CodexSubAgentActivityKind.started,
    "interacted" => CodexSubAgentActivityKind.interacted,
    "interrupted" => CodexSubAgentActivityKind.interrupted,
    "completed" => CodexSubAgentActivityKind.completed,
    _ => CodexSubAgentActivityKind.unknown,
  };
}

String? _textFromJson(Object? value) => value is String ? value : null;

List<String> _threadIdListFromJson(Object? value) {
  if (value is! List) return const [];
  return [for (final entry in value) if (entry is String) entry];
}

/// Decodes `agentsStates`, a map from receiver thread id to that agent's
/// status. The status is accepted as a bare string or as a tagged object whose
/// `type` names the variant; anything else becomes `unknown`.
class const CodexCollabAgentStatesConverter() implements JsonConverter<Map<String, CodexCollabAgentStatus>, Object?> {
  @override
  Map<String, CodexCollabAgentStatus> fromJson(Object? json) {
    if (json is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (key is String) key: _statusFromJson(value),
    };
  }

  static CodexCollabAgentStatus _statusFromJson(Object? value) {
    final tag = value is Map ? value["type"] : value;
    return switch (tag) {
      "pendingInit" => CodexCollabAgentStatus.pendingInit,
      "running" => CodexCollabAgentStatus.running,
      "completed" => CodexCollabAgentStatus.completed,
      "failed" => CodexCollabAgentStatus.failed,
      "interrupted" => CodexCollabAgentStatus.interrupted,
      "errored" => CodexCollabAgentStatus.errored,
      "shutdown" => CodexCollabAgentStatus.shutdown,
      "notFound" => CodexCollabAgentStatus.notFound,
      _ => CodexCollabAgentStatus.unknown,
    };
  }

  @override
  Object toJson(Map<String, CodexCollabAgentStatus> object) {
    return {for (final MapEntry(:key, :value) in object.entries) key: value.name};
  }
}

@freezed
sealed class CodexSubAgentItemParamsDto with _$CodexSubAgentItemParamsDto {
  const factory({
    required String? threadId,
    required String? turnId,
    required CodexSubAgentItemDto item,
  }) = _CodexSubAgentItemParamsDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemParamsDtoFromJson(json);
}

/// Flat wire shape shared by the collab tool-call and sub-agent activity items.
/// Fields that belong to only one item type decode as `null`/empty on the
/// other; the parser turns this into the sealed event.
@freezed
sealed class CodexSubAgentItemDto with _$CodexSubAgentItemDto {
  const factory({
    @JsonKey(
      unknownEnumValue: CodexSubAgentItemType.unknown,
      defaultValue: CodexSubAgentItemType.unknown,
    )
    required CodexSubAgentItemType type,
    required String? id,
    // collabAgentToolCall / collabToolCall
    @JsonKey(fromJson: _collabToolFromJson) required CodexCollabTool tool,
    @JsonKey(fromJson: _collabItemStatusFromJson) required CodexCollabItemStatus status,
    @JsonKey(fromJson: _textFromJson) required String? senderThreadId,
    @JsonKey(fromJson: _threadIdListFromJson) required List<String> receiverThreadIds,
    @JsonKey(fromJson: _textFromJson) required String? receiverThreadId,
    @JsonKey(fromJson: _textFromJson) required String? newThreadId,
    @JsonKey(fromJson: _textFromJson) required String? prompt,
    @CodexCollabAgentStatesConverter() required Map<String, CodexCollabAgentStatus> agentsStates,
    // subAgentActivity
    @JsonKey(fromJson: _activityKindFromJson) required CodexSubAgentActivityKind kind,
    @JsonKey(fromJson: _textFromJson) required String? agentThreadId,
    @JsonKey(fromJson: _textFromJson) required String? agentPath,
  }) = _CodexSubAgentItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSubAgentItemDtoFromJson(json);
}
