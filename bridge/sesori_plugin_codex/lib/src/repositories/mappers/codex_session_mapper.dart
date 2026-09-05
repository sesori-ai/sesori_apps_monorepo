import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/codex_session_record.dart";
import "../models/codex_thread_record.dart";
import "codex_sub_agent_name_mapper.dart";

/// Pure Layer-2 projections among normalized Codex records and bridge session
/// contracts and lifecycle events.
class const CodexSessionMapper() {
  CodexThreadRecord mapPersistedThread({required CodexSessionRecord record}) => CodexThreadRecord(
    id: record.id,
    name: _usefulText(record.threadName) ?? _usefulText(record.agentNickname),
    directory: switch (_usefulText(record.cwd)) {
      final directory? => normalizeProjectDirectory(directory: directory),
      null => null,
    },
    createdAt: record.createdAt?.millisecondsSinceEpoch,
    updatedAt: record.updatedAt?.millisecondsSinceEpoch,
    model: record.model,
    modelProvider: record.modelProvider,
    parentId: record.parentId,
    agentNickname: _usefulText(record.agentNickname),
    agentPath: _usefulText(record.agentPath),
  );

  String? _usefulText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  PluginSession mapThread({
    required CodexThreadRecord record,
    required String fallbackDirectory,
    required String? parentSessionId,
  }) {
    final directory = record.directory ?? normalizeProjectDirectory(directory: fallbackDirectory);
    final created = record.createdAt;
    final updated = record.updatedAt;
    return PluginSession(
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: parentSessionId,
      title: record.parentId == null
          ? record.name
          : const CodexSubAgentNameMapper().map(
              name: record.name,
              nickname: record.agentNickname,
              agentPath: record.agentPath,
            ),
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
    );
  }

  List<BridgeSseEvent> mapChildStarted({
    required CodexThreadRecord child,
    required String fallbackDirectory,
    required PluginSessionStatus status,
  }) => [
    BridgeSseSessionCreated(
      info: mapThread(
        record: child,
        fallbackDirectory: fallbackDirectory,
        parentSessionId: child.parentId,
      ).toJson(),
    ),
    BridgeSseSessionStatus(sessionID: child.id, status: status.toJson()),
  ];
}
