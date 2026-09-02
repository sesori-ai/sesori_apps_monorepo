import "package:freezed_annotation/freezed_annotation.dart";

part "claude_subagent_meta_dto.freezed.dart";
part "claude_subagent_meta_dto.g.dart";

/// `agent-<agentId>.meta.json`, written beside a sub-agent transcript.
///
/// Every field is tolerant: a meta file with a missing or wrong-typed field
/// still names a real sub-agent.
@Freezed(fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeSubagentMetaDto with _$ClaudeSubagentMetaDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? agentType,
    @JsonKey(fromJson: _stringOrNull) required String? description,
    @JsonKey(fromJson: _stringOrNull) required String? toolUseId,
    @JsonKey(fromJson: _intOrNull) required int? spawnDepth,
  }) = _ClaudeSubagentMetaDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeSubagentMetaDtoFromJson(json);
}

String? _stringOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;
