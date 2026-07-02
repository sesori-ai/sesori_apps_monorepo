import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

/// Maps a session's working directory to the canonical project directory it
/// belongs to, folding git worktree directories back into their parent project.
///
/// For a bridge-derived plugin (Codex, ACP) a session's own cwd is the only
/// location the backend reports. When the bridge created that session inside a
/// dedicated worktree, its cwd is the throwaway `<project>/.worktrees/<name>`
/// path — not the project the user opened. The bridge records the owning project
/// on every session it creates, so this mapper rebuilds a normalized
/// worktree→project index from those rows and rewrites any worktree cwd to its
/// parent. That keeps every worktree's sessions under one project card instead
/// of spawning a card per worktree, and lets project session lists include a
/// session running in a worktree.
class WorktreeProjectMapper {
  WorktreeProjectMapper({
    required List<({String worktreePath, String projectId})> worktreeProjectPaths,
  }) : _worktreeToProject = {
         for (final row in worktreeProjectPaths)
           normalizeProjectDirectory(directory: row.worktreePath): normalizeProjectDirectory(directory: row.projectId),
       };

  /// A mapper that knows of no worktrees — every directory is its own project.
  const WorktreeProjectMapper.empty() : _worktreeToProject = const {};

  final Map<String, String> _worktreeToProject;

  /// The canonical project directory for [directory]: the parent project when
  /// [directory] is a known worktree, else the normalized directory itself.
  String canonicalDirectory(String directory) {
    final normalized = normalizeProjectDirectory(directory: directory);
    return _worktreeToProject[normalized] ?? normalized;
  }
}
