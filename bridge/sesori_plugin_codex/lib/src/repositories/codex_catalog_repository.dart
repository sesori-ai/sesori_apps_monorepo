import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession, PluginSessionTime;

import "../session_rollout_reader.dart";

/// Layer-2 mapping and pagination for Codex's on-disk session catalog.
class CodexCatalogRepository {
  CodexCatalogRepository({
    required SessionRolloutReader rolloutReader,
    required String launchDirectory,
  }) : _rolloutReader = rolloutReader,
       _launchDirectory = launchDirectory;

  final SessionRolloutReader _rolloutReader;
  final String _launchDirectory;

  Future<List<PluginSession>> listAllSessions() async {
    final records = await _rolloutReader.listSessionsInIsolate();
    return records.map(_toPluginSession).toList(growable: false);
  }

  /// Filters by normalized rollout CWD before applying pagination. Rollouts
  /// without a CWD belong to the launch directory.
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final records = await _rolloutReader.listSessionsInIsolate();
    final target = normalizeProjectDirectory(directory: projectId);
    final sessions = records
        .where(
          (record) =>
              normalizeProjectDirectory(
                directory: record.cwd ?? _launchDirectory,
              ) ==
              target,
        )
        .map(_toPluginSession)
        .toList(growable: false);
    final from = start ?? 0;
    final until = limit == null ? sessions.length : (from + limit).clamp(0, sessions.length);
    if (from >= sessions.length) return const [];
    return sessions.sublist(from, until);
  }

  PluginSession _toPluginSession(CodexSessionRecord record) {
    final created = record.createdAt?.millisecondsSinceEpoch;
    final updated = record.updatedAt?.millisecondsSinceEpoch ?? created;
    final directory = normalizeProjectDirectory(
      directory: record.cwd ?? _launchDirectory,
    );
    return PluginSession(
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
}
