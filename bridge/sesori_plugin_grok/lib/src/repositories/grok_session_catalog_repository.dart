import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/grok_session_store_api.dart";
import "../api/models/grok_session_notification_dto.dart";
import "../api/models/grok_session_store_dto.dart";

/// The durable view of Grok sub-agent parentage. Grok's `session/list` returns
/// roots only and a child's `summary.json` names no parent, so after a bridge
/// restart the only record linking a child to its root is the
/// `subagent_spawned` update the root persisted. This repository reads that
/// link and the child's own summary; the live tracker covers what is running.
class GrokSessionCatalogRepository({required final GrokSessionStoreApi _api}) {
  /// Resolves the persisted project directory that contains [sessionId].
  String? persistedDirectoryForSession({required String sessionId}) {
    for (final cwd in _api.listProjectDirectories()) {
      if (!_api.listSessionIds(cwd: cwd).contains(sessionId)) continue;
      final summaryCwd = _usefulText(_api.readSummary(cwd: cwd, sessionId: sessionId)?.info?.cwd);
      return normalizeProjectDirectory(directory: summaryCwd ?? cwd);
    }
    return null;
  }

  /// The persisted children of [rootId] under [cwd], in spawn order.
  List<PluginSession> childSessions({required String cwd, required String rootId}) {
    final directory = normalizeProjectDirectory(directory: cwd);
    final seen = <String>{};
    return [
      for (final spawn in _api.readSpawnRecords(cwd: cwd, sessionId: rootId))
        if (spawn.childSessionId.isNotEmpty && seen.add(spawn.childSessionId))
          _childSession(cwd: cwd, directory: directory, rootId: rootId, spawn: spawn),
    ];
  }

  /// The persisted parent of [sessionId] under [cwd]; null for a root or an
  /// unknown session.
  String? parentOf({required String cwd, required String sessionId}) {
    final summary = _api.readSummary(cwd: cwd, sessionId: sessionId);
    if (summary?.sessionKind != GrokSessionKind.subagent) return null;
    for (final candidate in _api.listSessionIds(cwd: cwd)) {
      if (candidate == sessionId) continue;
      for (final spawn in _api.readSpawnRecords(cwd: cwd, sessionId: candidate)) {
        if (spawn.childSessionId == sessionId) return candidate;
      }
    }
    return null;
  }

  PluginSession _childSession({
    required String cwd,
    required String directory,
    required String rootId,
    required GrokSubagentSpawned spawn,
  }) {
    final summary = _api.readSummary(cwd: cwd, sessionId: spawn.childSessionId);
    final created = _timestampMs(summary?.createdAt);
    final updated = _timestampMs(summary?.updatedAt) ?? created;
    final effectiveCreated = created ?? updated;
    return PluginSession(
      id: spawn.childSessionId,
      projectID: directory,
      directory: directory,
      parentID: rootId,
      title: _usefulText(summary?.generatedTitle) ?? _usefulText(spawn.description),
      time: effectiveCreated == null || updated == null
          ? null
          : PluginSessionTime(created: effectiveCreated, updated: updated, archived: null),
    );
  }

  static int? _timestampMs(String? raw) => raw == null ? null : DateTime.tryParse(raw)?.millisecondsSinceEpoch;

  static String? _usefulText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
