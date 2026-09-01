/// `agent-<agentId>.meta.json`, written beside a sub-agent transcript.
///
/// Tolerant by hand: four optional fields do not earn a generated union, and a
/// meta file with a missing field still names a real sub-agent.
final class const ClaudeSubagentMetaDto({
  required final String? agentType,
  required final String? description,
  required final String? toolUseId,
  required final int? spawnDepth,
}) {
  static ClaudeSubagentMetaDto fromJson(Map<String, Object?> json) => ClaudeSubagentMetaDto(
    agentType: _stringOrNull(json["agentType"]),
    description: _stringOrNull(json["description"]),
    toolUseId: _stringOrNull(json["toolUseId"]),
    spawnDepth: switch (json["spawnDepth"]) {
      final num depth => depth.toInt(),
      _ => null,
    },
  );
}

String? _stringOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;
