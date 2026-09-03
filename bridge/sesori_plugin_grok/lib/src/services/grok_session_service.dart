import "package:acp_plugin/acp_plugin.dart" show AcpChildSessionTracker;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession;

import "../repositories/grok_session_catalog_repository.dart";

/// Layer-3 coordination for Grok child-session lineage across the persisted
/// session tree and the current ACP process's live tracker.
class GrokSessionService({
  required final GrokSessionCatalogRepository _catalogRepository,
  required final AcpChildSessionTracker _liveTracker,
}) {
  List<PluginSession> childSessions({
    required String rootSessionId,
    required String fallbackDirectory,
  }) => _mergeChildren(
    rootSessionId: rootSessionId,
    directory: _directoryForSession(sessionId: rootSessionId, fallbackDirectory: fallbackDirectory),
  );

  /// Adds persisted and not-yet-flushed live children to the roots returned by
  /// ACP `session/list`, so bridge-derived catalog import sees the full family.
  List<PluginSession> includeChildrenInAllSessions({required Iterable<PluginSession> sessions}) {
    final listedSessions = sessions.toList(growable: false);
    final roots = [
      for (final session in listedSessions)
        if (session.parentID == null) session,
    ];
    final persistedDirectories = _catalogRepository.persistedDirectoriesForSessions(
      sessionIds: {for (final root in roots) root.id},
    );
    final byId = {for (final session in listedSessions) session.id: session};
    for (final root in roots) {
      final directory = persistedDirectories[root.id] ?? normalizeProjectDirectory(directory: root.directory);
      final children = _mergeChildren(rootSessionId: root.id, directory: directory);
      if (directory != root.directory) {
        byId[root.id] = root.copyWith(projectID: directory, directory: directory);
      }
      for (final child in children) {
        byId.putIfAbsent(child.id, () => child);
      }
    }
    return byId.values.toList(growable: false);
  }

  String _directoryForSession({
    required String sessionId,
    required String fallbackDirectory,
  }) =>
      _catalogRepository.persistedDirectoryForSession(sessionId: sessionId) ??
      normalizeProjectDirectory(directory: fallbackDirectory);

  List<PluginSession> _mergeChildren({
    required String rootSessionId,
    required String directory,
  }) {
    final byId = <String, PluginSession>{
      for (final session in _catalogRepository.childSessions(cwd: directory, rootId: rootSessionId))
        session.id: session,
    };
    for (final session in _liveTracker.childSessions(sessionId: rootSessionId, directory: directory)) {
      byId.putIfAbsent(session.id, () => session);
    }
    return byId.values.toList(growable: false);
  }
}
