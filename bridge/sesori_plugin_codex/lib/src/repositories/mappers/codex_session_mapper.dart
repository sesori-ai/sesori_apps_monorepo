import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/codex_session_record.dart";
import "../models/codex_thread_record.dart";

/// Pure Layer-2 projections among normalized Codex records and bridge session
/// contracts and lifecycle events.
class const CodexSessionMapper() {
  CodexThreadRecord mapPersistedThread({required CodexSessionRecord record}) => CodexThreadRecord(
    id: record.id,
    name: record.threadName ?? record.agentNickname,
    directory: record.cwd,
    createdAt: record.createdAt?.millisecondsSinceEpoch,
    updatedAt: record.updatedAt?.millisecondsSinceEpoch,
    model: record.model,
    modelProvider: record.modelProvider,
    parentId: record.parentId,
    agentNickname: record.agentNickname,
  );

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
      title: record.name,
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
