import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession, PluginSessionTime;

import "../session_rollout_reader.dart";

/// Layer-2 mapping and pagination for Codex's on-disk session catalog.
class CodexCatalogRepository {
  CodexCatalogRepository({
    required SessionRolloutReader rolloutReader,
  }) : _rolloutReader = rolloutReader;

  final SessionRolloutReader _rolloutReader;

  Future<List<PluginSession>> listAllSessions() async {
    final records = await _rolloutReader.listSessionsInIsolate();
    return records.map(_toPluginSession).nonNulls.toList(growable: false);
  }

  /// Filters by normalized rollout CWD before applying pagination.
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final records = await _rolloutReader.listSessionsInIsolate();
    final target = normalizeProjectDirectory(directory: projectId);
    final sessions = records
        .map(_toPluginSession)
        .nonNulls
        .where((session) => session.directory == target)
        .toList(growable: false);
    final from = (start ?? 0).clamp(0, sessions.length);
    final pageSize = limit?.clamp(0, sessions.length);
    final until = pageSize == null ? sessions.length : (from + pageSize).clamp(from, sessions.length);
    if (from >= sessions.length) return const [];
    return sessions.sublist(from, until);
  }

  PluginSession? _toPluginSession(CodexSessionRecord record) {
    final cwd = record.cwd?.trim();
    if (cwd == null || cwd.isEmpty) return null;
    final created = record.createdAt?.millisecondsSinceEpoch;
    final updated = record.updatedAt?.millisecondsSinceEpoch ?? created;
    final directory = normalizeProjectDirectory(directory: cwd);
    return PluginSession(
      branchName: _usefulText(record.branch),
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: record.threadName,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
    );
  }

  String? _usefulText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
