import "package:freezed_annotation/freezed_annotation.dart";

import "openapi/agent_info.g.dart";

part "v2_agent_names.freezed.dart";

/// One catalog's plugin-local translation between native IDs and display names.
@Freezed(copyWith: false)
sealed class const V2AgentNames._() with _$V2AgentNames {
  const factory({required Map<String, String> namesById}) = _V2AgentNames;

  factory fromAgents({required List<AgentInfo> agents}) =>
      V2AgentNames(namesById: {for (final agent in agents) agent.id: agent.name});

  /// Retain the available identity for historical agents absent from the catalog.
  String displayName({required String id}) => namesById[id] ?? id;

  /// Backend-originated session selections can already contain a native ID.
  String? nativeId({required String selection}) {
    for (final entry in namesById.entries) {
      if (entry.value == selection) return entry.key;
    }
    return namesById.containsKey(selection) ? selection : null;
  }
}
