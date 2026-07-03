import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession;

/// Builds the list of a bridge-derived plugin's sessions that belong to one
/// project. Pure transformation — callers fetch the inputs.
///
/// Attribution rule, shared by the session and question repositories so both
/// scope a derived plugin's sessions identically:
///
/// - A session with a stored row is attributed to that row's project path
///   ([projectPathBySessionId], from the sessions⋈projects join). The bridge
///   records the owning project on every session it creates, so a session
///   running in a dedicated git worktree folds back under the project the user
///   opened instead of its throwaway `.worktrees/<name>` cwd.
/// - A session without a row (created outside the bridge) belongs to its own
///   working directory — a derive-style backend reports each session only
///   under its cwd, and for a non-bridge session that cwd IS the project.
class DerivedSessionBuilder {
  const DerivedSessionBuilder();

  /// The subset of [sessions] whose canonical project directory is
  /// [projectId], in the plugin's own enumeration order.
  List<PluginSession> build({
    required String projectId,
    required List<PluginSession> sessions,
    required Map<String, String> projectPathBySessionId,
  }) {
    final target = normalizeProjectDirectory(directory: projectId);
    return [
      for (final session in sessions)
        if (_canonicalDirectory(session: session, projectPathBySessionId: projectPathBySessionId) == target) session,
    ];
  }

  String _canonicalDirectory({
    required PluginSession session,
    required Map<String, String> projectPathBySessionId,
  }) {
    final storedPath = projectPathBySessionId[session.id];
    return normalizeProjectDirectory(directory: storedPath ?? session.directory);
  }
}
