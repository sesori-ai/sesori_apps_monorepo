import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgeDerivedProjectSource, PluginSession;

import "../persistence/daos/session_dao.dart";
import "mappers/worktree_project_mapper.dart";

/// Resolves which of a bridge-derived plugin's sessions belong to a project,
/// folding sessions that run in a dedicated git worktree back under the project
/// the user opened.
///
/// A derive-style backend (Codex, ACP) reports each session only under its own
/// cwd; a worktree session's cwd is the throwaway `.worktrees/<name>` path, not
/// the project. The bridge records the owning project on every session it
/// creates, so this scope rebuilds the worktree→project index from those rows
/// ([WorktreeProjectMapper]) and attributes each session to its canonical
/// project. It is the single home of that scoping, shared by the session and
/// question repositories so both attribute a derived plugin's sessions
/// identically.
class DerivedSessionScope {
  DerivedSessionScope({
    required BridgeDerivedProjectSource source,
    required SessionDao sessionDao,
    required String pluginId,
  }) : _source = source,
       _sessionDao = sessionDao,
       _pluginId = pluginId;

  final BridgeDerivedProjectSource _source;
  final SessionDao _sessionDao;
  final String _pluginId;

  /// The plugin's sessions whose canonical project directory is [projectId], in
  /// the plugin's own enumeration order.
  Future<List<PluginSession>> sessionsForProject(String projectId) async {
    final mapper = await _mapper();
    final target = normalizeProjectDirectory(directory: projectId);
    return [
      for (final session in await _source.listAllSessions())
        if (mapper.canonicalDirectory(session.directory) == target) session,
    ];
  }

  Future<WorktreeProjectMapper> _mapper() async {
    final worktreeProjectPaths = await _sessionDao.getWorktreeProjectPaths(pluginId: _pluginId);
    return WorktreeProjectMapper(worktreeProjectPaths: worktreeProjectPaths);
  }
}
